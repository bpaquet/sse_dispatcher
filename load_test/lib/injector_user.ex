defmodule InjectorUser do
  require Logger

  defmodule InjectorUserState do
    defstruct [
      :user_name,
      :publish_url,
      :rest_timeout,
      :delay_between_messages_min,
      :delay_between_messages_max,
      :start_time,
      :jwk
    ]
  end

  def start(context, user_name, publish_url, messages) do
    Logger.debug(fn ->
      "injector_#{user_name}: Starting injector user, #{length(messages)} messages to publish"
    end)

    start_time = :os.system_time(:millisecond)
    sleep = :rand.uniform(1000) + 500
    :timer.sleep(sleep)

    state = %InjectorUserState{
      user_name: user_name,
      publish_url: publish_url,
      rest_timeout: context.rest_timeout,
      delay_between_messages_min: context.delay_between_messages_min,
      delay_between_messages_max: context.delay_between_messages_max,
      start_time: start_time,
      jwk: jwk()
    }

    Logger.info(fn ->
      "injector_#{state.user_name}: Start publishing #{length(messages)} messages to #{state.publish_url}"
    end)

    run(state, messages)
  end

  defp run(state, []) do
    duration = :os.system_time(:millisecond) - state.start_time

    Logger.info(fn ->
      "injector_#{state.user_name}: All messages published to #{state.publish_url}, duration: #{duration / 1000}"
    end)
  end

  defp run(state, [first_message | messages]) do
    sleep =
      :rand.uniform(state.delay_between_messages_max - state.delay_between_messages_min) +
        state.delay_between_messages_min

    Logger.debug(fn -> "injector_#{state.user_name}: sleep=#{sleep}ms" end)
    :timer.sleep(sleep)

    raw_message =



    {:ok, request_payload} = Jason.encode(%{
      topic: state.user_name,
      message: "#{:os.system_time(:millisecond)} #{first_message} #{length(messages)} #{state.publish_url}"
    })


    Logger.debug(fn ->
      "injector_#{state.user_name}: Publishing #{inspect(raw_message)}, remaining #{length(messages)}"
    end)

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{jwt_token(state.jwk)}"}
    ]

    result =
      Finch.build(:post, state.publish_url, headers, request_payload)
      |> Finch.request(PublishFinch,
        receive_timeout: state.rest_timeout,
        pool_timeout: state.rest_timeout
      )

    case result do
      {:ok, http_result} ->
        case http_result.status do
          200 ->
            Logger.debug(fn ->
              "injector_#{state.user_name}: Message published: #{inspect(first_message)}"
            end)

            LoadTestStats.inc_msg_published_ok()

          other ->
            LoadTestStats.inc_msg_published_error()

            raise(
              "injector_#{state.user_name}: Error publishing message #{inspect(first_message)}, status: #{other}"
            )
        end

      msg ->
        LoadTestStats.inc_msg_published_error()
        raise("injector_#{state.user_name}: Unknown message #{inspect(msg)}")
    end

    run(state, messages)
  end


  defp jwk() do
    shared_secret= "nLjJdNLlpdv3W4Xk7MyVCAZKD-hvza6FQ4yhUUFnjmg"
    JOSE.JWK.from_oct(shared_secret)
  end

  defp jwt_token(jwk) do

    iat = :os.system_time(:second)
    exp = iat + (2*60 -1)
    issuer = "test_issuer1"

    jws = %{
      "alg" => "HS256"
    }

    jwt = %{
      "iss" => issuer,
      "exp" => exp,
      "iat" => iat,
      "aud" => "private_interface"
    }

    signed = JOSE.JWT.sign(jwk, jws, jwt)
    {%{alg: :jose_jws_alg_hmac}, compact_signed} = JOSE.JWS.compact(signed)

    compact_signed
  end
end

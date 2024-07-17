defmodule SseUser do
  require Logger

  defmodule SseUserState do
    defstruct [
      :user_name,
      :start_time,
      :all_messages,
      :current_message,
      :url,
      :sse_timeout,
      :start_injector_callback
    ]
  end

  def run(context, user_name, topic, expected_messages) do
    url = "#{context.sse_base_url}"

    Logger.debug(fn ->
      "#{user_name}: Starting SSE client on url #{url}, expecting #{length(expected_messages)} messages"
    end)

    headers = [
      {~c"Authorization", ~c"Bearer #{jwt_token(user_name)}"}
    ]

    http_request_opts = []

    case :httpc.request(:get, {url, headers}, http_request_opts, [{:sync, false}, {:stream, :self}]) do
      {:ok, request_id} ->

        state = %SseUserState{
          user_name: user_name,
          start_time: :os.system_time(:millisecond),
          all_messages: length(expected_messages),
          current_message: -1,
          url: url,
          sse_timeout: context.sse_timeout,
          start_injector_callback: fn ->
            Main.start_injector(context, user_name, topic, expected_messages)
          end
        }

        # Adding a padding message for the connection message
        wait_for_messages(state, request_id, ["" | expected_messages])
      error ->
        Logger.error(inspect(error))
    end


  end

  defp wait_for_messages(state, request_id, [first_message | remaining_messages]) do
    Logger.debug(fn -> "#{header(state)} Waiting for message: #{first_message}" end)

    receive do
      {:http, {_, {:error, msg}}} ->
        Logger.error("#{header(state)} Http error: #{inspect(msg)}")
        :ok = :httpc.cancel_request(request_id)
        LoadTestStats.inc_msg_received_http_error()
        raise("#{header(state)} Http error")

      {:http, {_, :stream, msg}} ->
        msg = String.trim(msg)
        Logger.debug(fn -> "#{header(state)} Received message: #{inspect(msg)}" end)
        check_message(state, msg, first_message)

      {:http, {_, :stream_start, headers}} ->
        {~c"x-sse-server", server} = List.keyfind(headers, ~c"x-sse-server", 0)

        Logger.info(fn ->
          "#{header(state)} Connected, waiting: #{length(remaining_messages) + 1} messages, url #{state.url}, remote server: #{server}"
        end)

        state.start_injector_callback.()

      msg ->
        Logger.error("#{header(state)} Unexpected message #{inspect(msg)}")
        :ok = :httpc.cancel_request(request_id)
        raise("#{header(state)} Unexpected message")
    after
      state.sse_timeout ->
        Logger.error(
          "#{header(state)} Timeout waiting for message (timeout=#{state.sse_timeout}ms), remaining: #{length(remaining_messages) + 1} messages, url #{state.url}"
        )

        LoadTestStats.inc_msg_received_timeout()

        :ok = :httpc.cancel_request(request_id)
        raise("#{header(state)} Timeout waiting for message")
    end

    state = Map.put(state, :current_message, state.current_message + 1)
    wait_for_messages(state, request_id, remaining_messages)
  end

  defp wait_for_messages(state, request_id, []) do
    :ok = :httpc.cancel_request(request_id)
    Logger.info("#{header(state)} All messages received, url #{state.url}")
  end

  defp header(state) do
    now = :os.system_time(:millisecond)

    "#{state.user_name} / #{now - state.start_time} ms / #{state.current_message} < #{state.all_messages}: "
  end

  defp check_message(state, received_message, expected_message) do
    clean_received_message = String.replace(received_message, ~r"id: .*\n", "")

    try do
      [_, ts, message, _, _] = String.split(clean_received_message, " ", parts: 5)
      current_ts = :os.system_time(:millisecond)
      delay = current_ts - String.to_integer(ts)
      LoadTestStats.observe_propagation(delay)

      Logger.debug(fn ->
        "#{header(state)} Propagation delay for message #{message} is #{delay}ms"
      end)

      if message == expected_message do
        LoadTestStats.inc_msg_received_ok()
      else
        LoadTestStats.inc_msg_received_unexpected_message()

        Logger.error(
          "#{header(state)} Received unexpected message on url #{state.url}: #{inspect(received_message)} instead of #{expected_message}"
        )
      end
    rescue
      e ->
        Logger.error("#{header(state)} #{inspect(e)}")
        LoadTestStats.inc_msg_received_error()
    end
  end


  defp jwk() do
    private_key= """
    -----BEGIN RSA PRIVATE KEY-----
    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
    -----END RSA PRIVATE KEY-----
    """
    JOSE.JWK.from_pem(private_key)
  end

  defp jwt_token(user_name) do


    iat = :os.system_time(:second)
    exp = iat + (2*60 -1)
    issuer = "test_issuer1"

    jwk = jwk()

    jws = %{
      "alg" => "RS256"
    }

    jwt = %{
      "iss" => issuer,
      "exp" => exp,
      "iat" => iat,
      "aud" => "public_interface",
      "sub" => user_name
    }

    signed = JOSE.JWT.sign(jwk, jws, jwt)
    {%{alg: :jose_jws_alg_rsa_pkcs1_v1_5}, compact_signed} = JOSE.JWS.compact(signed)

    compact_signed
  end
end

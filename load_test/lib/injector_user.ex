defmodule InjectorUser do
  require Logger

  defmodule InjectorUserState do
    defstruct [
      :user_name,
      :publish_url,
      :rest_timeout,
      :delay_between_messages_min,
      :delay_between_messages_max,
      :start_time
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
      start_time: start_time
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
      "#{:os.system_time(:millisecond)} #{first_message} #{length(messages)} #{state.publish_url}"

    Logger.debug(fn ->
      "injector_#{state.user_name}: Publishing #{inspect(raw_message)}, remaining #{length(messages)}"
    end)

    headers = [
      {"Content-Type", "application/octet-stream"}
    ]

    result =
      Finch.build(:post, state.publish_url, headers, raw_message)
      |> Finch.request(PublishFinch)

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
end

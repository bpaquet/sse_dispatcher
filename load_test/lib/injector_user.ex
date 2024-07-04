defmodule InjectorUser do
  require Logger

  def start(
        user_name,
        publish_url,
        rest_timeout,
        messages,
        delay_between_messages_min,
        delay_between_messages_max
      ) do
    Logger.debug(fn ->
      "injector_#{user_name}: Starting injector user, #{length(messages)} messages to publish"
    end)

    start_time = :os.system_time(:millisecond)
    sleep = :rand.uniform(1000) + 500
    :timer.sleep(sleep)

    Logger.info(fn ->
      "injector_#{user_name}: Start publishing #{length(messages)} messages to #{publish_url}"
    end)

    run(
      user_name,
      publish_url,
      rest_timeout,
      messages,
      delay_between_messages_min,
      delay_between_messages_max,
      start_time
    )
  end

  defp run(user_name, publish_url, _, [], _, _, start_time) do
    duration = :os.system_time(:millisecond) - start_time

    Logger.info(fn ->
      "injector_#{user_name}: All messages published to #{publish_url}, duration: #{duration / 1000}"
    end)
  end

  defp run(
         user_name,
         publish_url,
         rest_timeout,
         [first_message | messages],
         delay_between_messages_min,
         delay_between_messages_max,
         start_time
       ) do
    sleep =
      :rand.uniform(delay_between_messages_max - delay_between_messages_min) +
        delay_between_messages_min

    Logger.debug(fn -> "injector_#{user_name}: sleep=#{sleep}ms" end)
    :timer.sleep(sleep)

    raw_message =
      "#{:os.system_time(:millisecond)} #{first_message} #{length(messages)} #{publish_url}"

    Logger.debug(fn ->
      "injector_#{user_name}: Publishing #{inspect(raw_message)}, remaining #{length(messages)}"
    end)

    headers = []

    result =
      :httpc.request(
        :post,
        {publish_url, headers, ~c"application/octet-stream", raw_message},
        [{:timeout, rest_timeout}, {:connect_timeout, rest_timeout}],
        []
      )

    case result do
      {:error, error} ->
        Logger.error("injector_#{user_name}: Error publishing message: #{inspect(error)}")
        LoadTestStats.inc_msg_published_error()

      {:ok, {{_, 200, _}, _, _}} ->
        Logger.debug(fn -> "injector_#{user_name}: Message published: #{inspect(first_message)}" end)
        LoadTestStats.inc_msg_published_ok()

      msg ->
        LoadTestStats.inc_msg_published_error()
        Logger.error("injector_#{user_name}: Unknown message #{inspect(msg)}")
    end

    run(
      user_name,
      publish_url,
      rest_timeout,
      messages,
      delay_between_messages_min,
      delay_between_messages_max,
      start_time
    )
  end
end

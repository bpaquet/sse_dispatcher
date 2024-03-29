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

    run(
      user_name,
      publish_url,
      rest_timeout,
      messages,
      delay_between_messages_min,
      delay_between_messages_max
    )
  end

  defp run(user_name, _, _, [], _, _) do
    Logger.info(fn -> "injector_#{user_name}: All messages published" end)
  end

  defp run(
         user_name,
         publish_url,
         rest_timeout,
         [first_message | messages],
         delay_between_messages_min,
         delay_between_messages_max
       ) do
    sleep =
      :rand.uniform(delay_between_messages_max - delay_between_messages_min) +
        delay_between_messages_min

    Logger.debug(fn -> "injector_#{user_name}: Sleep=#{sleep}ms" end)
    :timer.sleep(sleep)

    Logger.debug(fn ->
      "injector_#{user_name}: Publishing #{first_message}, remaining #{length(messages)}"
    end)

    headers = []

    result =
      :httpc.request(
        :post,
        {publish_url, headers, ~c"application/octet-stream",
         "#{:os.system_time(:millisecond)} #{first_message}"},
        [{:timeout, rest_timeout}, {:connect_timeout, rest_timeout}],
        []
      )

    case result do
      {:error, error} ->
        LoadTestStats.inc_msg_published_error()
        Logger.error("injector_#{user_name}: Error publishing message: #{inspect(error)}")

      {:ok, {{_, 200, _}, _, _}} ->
        Logger.debug(fn -> "injector_#{user_name}: Message published: #{first_message}" end)
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
      delay_between_messages_max
    )
  end
end

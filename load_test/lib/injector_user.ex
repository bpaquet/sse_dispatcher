defmodule InjectorUser do
  require Logger

  def start(
        user_name,
        publish_url,
        messages,
        delay_between_messages_min,
        delay_between_messages_max
      ) do
    run(user_name, publish_url, messages, delay_between_messages_min, delay_between_messages_max)
  end

  defp run(user_name, _, [], _, _) do
    Logger.info("injector_#{user_name}: All messages published")
  end

  defp run(
         user_name,
         publish_url,
         [first_message | messages],
         delay_between_messages_min,
         delay_between_messages_max
       ) do
    sleep =
      :rand.uniform(delay_between_messages_max - delay_between_messages_min) +
        delay_between_messages_min

    # Logger.info("injector_#{user_name}: sleep=#{sleep}ms")
    :timer.sleep(sleep)
    # Logger.info("injector_#{user_name}: publishing #{first_message}")
    response = Req.post!(publish_url, body: "#{:os.system_time(:millisecond)} #{first_message}")

    if response.status == 200 do
      LoadTestStats.inc_msg_published_ok()
    else
      LoadTestStats.inc_msg_published_error()
      Logger.error("injector_#{user_name}: Error publishing message: #{inspect(response)}")
    end

    run(user_name, publish_url, messages, delay_between_messages_min, delay_between_messages_max)
  end
end

defmodule SseUser do
  require Logger

  def run(user_name, sse_timeout, url, expected_messages) do
    Logger.debug(
      "#{user_name}: Starting SSE client on url #{url}, expecting #{length(expected_messages)} messages"
    )

    headers = []
    http_request_opts = []

    {:ok, request_id} =
      :httpc.request(:get, {url, headers}, http_request_opts, [{:sync, false}, {:stream, :self}])

    wait_for_messages(user_name, sse_timeout, request_id, expected_messages)
  end

  defp wait_for_messages(user_name, sse_timeout, request_id, [first_message | remaining_messages]) do
    receive do
      {:http, {_, :stream, msg}} ->
        Logger.debug("#{user_name}: Received message: #{extract_message(msg)}")
        check_message(user_name, extract_message(msg), first_message)
        wait_for_messages(user_name, sse_timeout, request_id, remaining_messages)
    after
      sse_timeout ->
        Logger.error("#{user_name}: Timeout waiting for message (timeout=#{sse_timeout}ms)")
        :ok = :httpc.cancel_request(request_id)
        raise("#{user_name}: Timeout waiting for message")
    end
  end

  defp wait_for_messages(user_name, _, request_id, []) do
    :ok = :httpc.cancel_request(request_id)
    Logger.info("#{user_name}: All messages received")
  end

  defp extract_message(message) do
    String.slice(message, 24..-3//1)
  end

  def check_message(user_name, received_message, expected_message) do
    try do
      [ts, message] = String.split(received_message, " ", parts: 2)
      current_ts = :os.system_time(:millisecond)
      delay = current_ts - String.to_integer(ts)
      LoadTestStats.observe_propagation(delay)
      Logger.debug("#{user_name}: Propagation delay for message #{message} is #{delay}ms")

      if message == expected_message do
        LoadTestStats.inc_msg_received_ok()
      else
        LoadTestStats.inc_msg_received_error()
        Logger.error("#{user_name}: Received unexpected message: #{received_message}")
      end
    catch
      e -> Logger.error("#{user_name}: #{e}")
    end
  end
end

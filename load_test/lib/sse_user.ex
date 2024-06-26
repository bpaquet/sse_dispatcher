defmodule SseUser do
  require Logger

  def run(user_name, sse_timeout, url, expected_messages) do
    Logger.debug(fn ->
      "#{user_name}: Starting SSE client on url #{url}, expecting #{length(expected_messages)} messages"
    end)

    headers = []
    http_request_opts = []

    {:ok, request_id} =
      :httpc.request(:get, {url, headers}, http_request_opts, [{:sync, false}, {:stream, :self}])

    wait_for_messages(user_name, sse_timeout, url, request_id, expected_messages)
  end

  defp wait_for_messages(user_name, sse_timeout, url, request_id, [
         first_message | remaining_messages
       ]) do
    Logger.debug(fn -> "#{user_name}: Waiting for message: #{first_message}" end)

    receive do
      {:http, {request_id, {:error, msg}}} ->
        Logger.error("#{user_name}: Http error: #{inspect(msg)}")
        :ok = :httpc.cancel_request(request_id)
        raise("#{user_name}: Http error")

      {:http, {request_id, :stream, msg}} ->
        msg = String.trim(msg)
        Logger.debug(fn -> "#{user_name}: Received message: #{msg}" end)
        check_message(user_name, msg, first_message)
        wait_for_messages(user_name, sse_timeout, url, request_id, remaining_messages)

      {:http, {request_id, :stream_start, _}} ->
        Logger.info(fn ->
          "#{user_name}: Connected, waiting: #{length(remaining_messages) + 1} messages, url #{url}"
        end)

        wait_for_messages(user_name, sse_timeout, url, request_id, [
          first_message | remaining_messages
        ])

      msg ->
        Logger.error("#{user_name}: Unexpected message #{inspect(msg)}")
        :ok = :httpc.cancel_request(request_id)
        raise("#{user_name}: Unexpected message")
    after
      sse_timeout ->
        Logger.error(
          "#{user_name}: Timeout waiting for message (timeout=#{sse_timeout}ms), remaining: #{length(remaining_messages) + 1} messages, url #{url}"
        )

        :ok = :httpc.cancel_request(request_id)
        raise("#{user_name}: Timeout waiting for message")
    end
  end

  defp wait_for_messages(user_name, _, url, request_id, []) do
    :ok = :httpc.cancel_request(request_id)
    Logger.info("#{user_name}: All messages received, url #{url}")
  end

  def check_message(user_name, received_message, expected_message) do
    clean_received_message = String.replace(received_message, ~r"id: .*\n", "")

    try do
      [_, ts, message, _, _] = String.split(clean_received_message, " ", parts: 5)
      current_ts = :os.system_time(:millisecond)
      delay = current_ts - String.to_integer(ts)
      LoadTestStats.observe_propagation(delay)

      Logger.debug(fn ->
        "#{user_name}: Propagation delay for message #{message} is #{delay}ms"
      end)

      if message == expected_message do
        LoadTestStats.inc_msg_received_ok()
      else
        LoadTestStats.inc_msg_received_error()

        Logger.error(
          "#{user_name}: Received unexpected message: #{received_message} instead of #{expected_message}"
        )
      end
    rescue
      e ->
        Logger.error("#{user_name}: #{inspect(e)}")
    end
  end
end

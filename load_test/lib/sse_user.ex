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
    url = "#{context.sse_base_url}/#{topic}"

    Logger.debug(fn ->
      "#{user_name}: Starting SSE client on url #{url}, expecting #{length(expected_messages)} messages"
    end)

    headers = []
    http_request_opts = []

    {:ok, request_id} =
      :httpc.request(:get, {url, headers}, http_request_opts, [{:sync, false}, {:stream, :self}])

    state = %SseUserState{
      user_name: user_name,
      start_time: :os.system_time(:millisecond),
      all_messages: length(expected_messages),
      current_message: 0,
      url: url,
      sse_timeout: context.sse_timeout,
      start_injector_callback: fn ->
        Main.start_injector(context, user_name, topic, expected_messages)
      end
    }

    wait_for_messages(state, request_id, expected_messages)
  end

  defp wait_for_messages(state, request_id, [first_message | remaining_messages]) do
    Logger.debug(fn -> "#{header(state)} Waiting for message: #{first_message}" end)

    receive do
      {:http, {request_id, {:error, msg}}} ->
        Logger.error("#{header(state)} Http error: #{inspect(msg)}")
        :ok = :httpc.cancel_request(request_id)
        raise("#{header(state)} Http error")

      {:http, {request_id, :stream, msg}} ->
        msg = String.trim(msg)
        Logger.debug(fn -> "#{header(state)} Received message: #{inspect(msg)}" end)
        check_message(state, msg, first_message)
        state = Map.put(state, :current_message, state.current_message + 1)
        wait_for_messages(state, request_id, remaining_messages)

      {:http, {request_id, :stream_start, _}} ->
        Logger.info(fn ->
          "#{header(state)} Connected, waiting: #{length(remaining_messages) + 1} messages, url #{state.url}"
        end)

        state.start_injector_callback.()

        wait_for_messages(state, request_id, [first_message | remaining_messages])

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
        LoadTestStats.inc_msg_received_error()

        Logger.error(
          "#{header(state)} Received unexpected message on url #{state.url}: #{inspect(received_message)} instead of #{expected_message}"
        )
      end
    rescue
      e ->
        Logger.error("#{header(state)} #{inspect(e)}")
    end
  end
end

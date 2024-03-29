defmodule Main do
  use GenServer
  require Logger

  def start_link(start_from, opts \\ []) do
    GenServer.start_link(__MODULE__, start_from, opts)
  end

  def init(start_from) do
    {:ok, nb_user} = Application.fetch_env(:load_test, :nb_user)

    {:ok, sse_timeout} = Application.fetch_env(:load_test, :sse_timeout)
    {:ok, sse_base_url} = Application.fetch_env(:load_test, :sse_base_url)

    {:ok, rest_base_url} = Application.fetch_env(:load_test, :rest_base_url)
    {:ok, rest_timeout} = Application.fetch_env(:load_test, :rest_timeout)

    {:ok, delay_between_messages_min} =
      Application.fetch_env(:load_test, :delay_between_messages_min)

    {:ok, delay_between_messages_max} =
      Application.fetch_env(:load_test, :delay_between_messages_max)

    {:ok, number_of_messages_min} = Application.fetch_env(:load_test, :number_of_messages_min)
    {:ok, number_of_messages_max} = Application.fetch_env(:load_test, :number_of_messages_max)

    Logger.warning("SSE BASE URL: #{sse_base_url}")
    Logger.warning("REST BASE URL: #{rest_base_url}")
    Logger.warning("Starting load test with #{nb_user} users")

    Enum.map(1..nb_user, fn _ ->
      Task.Supervisor.async(LoadTest.TaskSupervisor, fn ->
        run_virtual_user(
          rest_base_url,
          rest_timeout,
          sse_base_url,
          sse_timeout,
          number_of_messages_min,
          number_of_messages_max,
          delay_between_messages_min,
          delay_between_messages_max
        )
      end)
    end)

    {:ok, start_from}
  end

  defp run_virtual_user(
         rest_base_url,
         rest_timeout,
         sse_base_url,
         sse_timeout,
         number_of_messages_min,
         number_of_messages_max,
         delay_between_messages_min,
         delay_between_messages_max
       ) do
    number_of_messages =
      :rand.uniform(number_of_messages_max - number_of_messages_min) + number_of_messages_min

    messages = Enum.map(1..number_of_messages, fn _ -> UUID.uuid4() end)
    topic = "topic_#{UUID.uuid4()}"
    user_name = "user_#{UUID.uuid4()}"

    sse_task =
      Task.async(fn -> run_sse_user(user_name, topic, sse_base_url, sse_timeout, messages) end)

    injector_task =
      Task.async(fn ->
        run_injector(
          user_name,
          topic,
          rest_base_url,
          rest_timeout,
          messages,
          delay_between_messages_min,
          delay_between_messages_max
        )
      end)

    Task.await(sse_task, :infinity)
    Task.await(injector_task, :infinity)

    run_virtual_user(
      rest_base_url,
      rest_timeout,
      sse_base_url,
      sse_timeout,
      number_of_messages_min,
      number_of_messages_max,
      delay_between_messages_min,
      delay_between_messages_max
    )
  end

  defp run_injector(
         user_name,
         topic,
         rest_base_url,
         rest_timeout,
         messages,
         delay_between_messages_min,
         delay_between_messages_max
       ) do
    try do
      InjectorUser.start(
        user_name,
        "#{rest_base_url}/#{topic}",
        rest_timeout,
        messages,
        delay_between_messages_min,
        delay_between_messages_max
      )

      :ok
    rescue
      _ ->
        :error
    end
  end

  defp run_sse_user(user_name, topic, sse_base_url, sse_timeout, messages) do
    LoadTestStats.inc_user_running()

    try do
      SseUser.run(
        user_name,
        sse_timeout,
        "#{sse_base_url}/#{topic}",
        messages
      )

      LoadTestStats.dec_user_running()
      LoadTestStats.inc_user_ok()
      :ok
    rescue
      _ ->
        LoadTestStats.dec_user_running()
        LoadTestStats.inc_user_error()
        :error
    end
  end

  def handle_info({_, :ok}, []) do
  end
end

defmodule Main do
  use GenServer
  require Logger

  defmodule InjectionContext do
    defstruct [
      :sse_timeout,
      :sse_base_url,
      :rest_base_url,
      :rest_timeout,
      :delay_between_messages_min,
      :delay_between_messages_max,
      :number_of_messages_min,
      :number_of_messages_max
    ]
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
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

    {:ok, initial_delay_max} = Application.fetch_env(:load_test, :initial_delay_max)

    context = %InjectionContext{
      sse_timeout: sse_timeout,
      sse_base_url: sse_base_url,
      rest_base_url: rest_base_url,
      rest_timeout: rest_timeout,
      delay_between_messages_min: delay_between_messages_min,
      delay_between_messages_max: delay_between_messages_max,
      number_of_messages_min: number_of_messages_min,
      number_of_messages_max: number_of_messages_max
    }

    Logger.warning("SSE BASE URL: #{sse_base_url}")
    Logger.warning("REST BASE URL: #{rest_base_url}")
    Logger.warning("Starting load test with #{nb_user} users")

    Enum.map(1..nb_user, fn _ ->
      Task.Supervisor.async(LoadTest.TaskSupervisor, fn ->
        delay = :rand.uniform(initial_delay_max)

        receive do
        after
          delay -> :ok
        end

        run_virtual_user(context)
      end)
    end)

    {:ok, start_from}
  end

  defp run_virtual_user(context) do
    number_of_messages =
      :rand.uniform(context.number_of_messages_max - context.number_of_messages_min) +
        context.number_of_messages_min

    messages = Enum.map(1..number_of_messages, fn _ -> UUID.uuid4() end)
    topic = "topic_#{UUID.uuid4()}"
    user_name = "user_#{UUID.uuid4()}"

    sse_task =
      Task.Supervisor.async(LoadTest.TaskSupervisor, fn ->
        run_sse_user(context, user_name, topic, messages)
      end)

    Task.await(sse_task, :infinity)

    run_virtual_user(context)
  end

  def start_injector(context, user_name, topic, messages) do
    GenServer.cast(__MODULE__, {:start_injector, context, user_name, topic, messages})
  end

  @impl true
  def handle_cast({:start_injector, context, user_name, topic, messages}, state) do
    Task.Supervisor.start_child(LoadTest.TaskSupervisor, fn ->
      run_injector(context, user_name, topic, messages)
    end)

    {:noreply, state}
  end

  defp run_injector(context, user_name, topic, messages) do
    try do
      InjectorUser.start(
        user_name,
        "#{context.rest_base_url}/#{topic}",
        context.rest_timeout,
        messages,
        context.delay_between_messages_min,
        context.delay_between_messages_max
      )

      :ok
    rescue
      x ->
        Logger.error("injector_#{user_name}: Error #{inspect(x)}")
        :error
    end
  end

  defp run_sse_user(context, user_name, topic, messages) do
    LoadTestStats.inc_user_running()

    try do
      SseUser.run(
        context,
        user_name,
        topic,
        messages
      )

      LoadTestStats.dec_user_running()
      LoadTestStats.inc_user_ok()
      :ok
    rescue
      x ->
        Logger.error("#{user_name}: Error #{inspect(x)}")
        LoadTestStats.dec_user_running()
        LoadTestStats.inc_user_error()
        :error
    end
  end

  @impl true
  def handle_info({_, :ok}, state) do
    {:noreply, state}
  end
end

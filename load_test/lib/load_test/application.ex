defmodule LoadTest.Application do
  @moduledoc false

  require Logger

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    {:ok, port} = Application.fetch_env(:load_test, :port)
    {:ok, http_pool_size} = Application.fetch_env(:load_test, :http_pool_size)
    Logger.warning("Current host: #{node()}")
    Logger.warning("Starting Load test on port: #{port}")
    Logger.warning("Http pool size: #{http_pool_size}")

    children = [
      {Plug.Cowboy, scheme: :http, plug: Rest, options: [port: port]},
      {Task.Supervisor, name: LoadTest.TaskSupervisor},
      {Main, []},
      {Finch,
       name: PublishFinch,
       pools: %{
         :default => [size: http_pool_size]
       }}
    ]

    MetricsPlugExporter.setup()
    LoadTestStats.setup()

    opts = [strategy: :one_for_one, name: LoadTest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

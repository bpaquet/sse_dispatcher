defmodule SSEDispatcher.Application do
  @moduledoc false

  require Logger

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    {sse_port, _} = Integer.parse(System.get_env("SSE_PORT") || "4000")
    {rest_port, _} = Integer.parse(System.get_env("REST_PORT") || "3000")
    Logger.info("Current host #{node()}")
    Logger.info("Starting SSEDispatcher on port #{sse_port} for SSE and #{rest_port} for REST")

    children = [
      {Phoenix.PubSub,
       name: SSEDispatcher.PubSub, options: [adapter: Phoenix.PubSub.PG2, pool_size: 10]},
      {Plug.Cowboy, scheme: :http, plug: Rest, options: [port: rest_port]},
      {Plug.Cowboy, scheme: :http, plug: Sse, options: [port: sse_port]}
    ]

    MetricsPlugExporter.setup()
    SSEStats.setup()

    opts = [strategy: :one_for_one, name: SSEDispatcher.Supervisor]
    Supervisor.start_link(add_cluster_supervisor(children), opts)
  end

  defp add_cluster_supervisor(children) do
    if System.get_env("EPMD_CLUSTER_MEMBERS") do
      Logger.info("Starting libcluster")

      topologies = [
        example: [
          strategy: Cluster.Strategy.Epmd,
          config: [
            hosts:
              Enum.map(
                String.split(System.get_env("EPMD_CLUSTER_MEMBERS"), ","),
                &String.to_atom/1
              )
          ]
        ]
      ]

      children ++ [{Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}]
    else
      children
    end
  end
end

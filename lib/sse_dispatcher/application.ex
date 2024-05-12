defmodule SSEDispatcher.Application do
  @moduledoc false

  require Logger

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    {:ok, sse_port} = Application.fetch_env(:sse_dispatcher, :sse_port)
    {:ok, rest_port} = Application.fetch_env(:sse_dispatcher, :rest_port)
    Logger.warning("Current host #{node()}")
    Logger.warning("Starting SSEDispatcher on port #{sse_port} for SSE and #{rest_port} for REST")

    children = [
      {Phoenix.PubSub,
       name: SSEDispatcher.PubSub, options: [adapter: Phoenix.PubSub.PG2, pool_size: 10]},
      {Plug.Cowboy, scheme: :http, plug: Rest, options: [port: rest_port]},
      {Plug.Cowboy,
       scheme: :http,
       plug: Sse,
       options: [
         port: sse_port,
         protocol_options: [idle_timeout: :infinity],
         transport_options: [max_connections: :infinity]
       ]}
    ]

    MetricsPlugExporter.setup()
    SSEStats.setup()

    opts = [strategy: :one_for_one, name: SSEDispatcher.Supervisor]
    Supervisor.start_link(add_cluster_supervisor(children), opts)
  end

  defp add_cluster_supervisor(children) do
    cond do
      System.get_env("EPMD_CLUSTER_MEMBERS") ->
        Logger.info("Starting libcluster with EMPD_CLUSTER_MEMBERS: #{System.get_env("EPMD_CLUSTER_MEMBERS")}")

        topologies = [
          epmd: [
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
      System.get_env("EC2_CLUSTER_TAG") && System.get_env("EC2_CLUSTER_VALUE") ->
        Logger.info("Starting libcluster with EC2_CLUSTER_TAG: #{System.get_env("EC2_CLUSTER_TAG")}")

        topologies = [
          example: [
            strategy: ClusterEC2.Strategy.Tags,
            config: [
              ec2_tagname: System.get_env("EC2_CLUSTER_TAG"),
              ec2_tagvalue: System.get_env("EC2_CLUSTER_VALUE"),
              show_debug: true,
            ],
          ]
        ]
        children ++ [{Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}]
      true -> children
    end
  end
end

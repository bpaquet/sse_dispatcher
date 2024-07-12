defmodule SSEDispatcher.Application do
  @moduledoc false

  require Logger

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    {:ok, sse_port} = Application.fetch_env(:sse_dispatcher, :sse_port)
    {:ok, rest_port} = Application.fetch_env(:sse_dispatcher, :rest_port)
    {:ok, prometheus_port} = Application.fetch_env(:sse_dispatcher, :prometheus_port)
    Logger.warning("Current host #{node()}")

    Logger.warning(
      "Starting HTTP Server #{rest_port} for REST, #{prometheus_port} for Prometheus"
    )

    {:ok, ssl_keyfile} = Application.fetch_env(:sse_dispatcher, :ssl_keyfile)
    {:ok, ssl_certfile} = Application.fetch_env(:sse_dispatcher, :ssl_certfile)

    base_sse_http_config = [
      port: sse_port,
      protocol_options: [idle_timeout: :infinity],
      transport_options: [max_connections: :infinity]
    ]

    {sse_http_scheme, sse_http_config} =
      if ssl_keyfile != nil do
        Logger.warning(
          "Starting HTTPS Server #{sse_port}, with keyfile: #{ssl_keyfile}, certfile: #{ssl_certfile}"
        )

        http_config =
          Keyword.merge(base_sse_http_config,
            keyfile: ssl_keyfile,
            certfile: ssl_certfile,
            otp_app: :sse_dispatcher
          )

        {:https, http_config}
      else
        Logger.warning("Starting HTTP Server #{sse_port} without SSL")
        {:http, base_sse_http_config}
      end

    children = [
      {Phoenix.PubSub,
       name: SSEDispatcher.PubSub, options: [adapter: Phoenix.PubSub.PG2, pool_size: 10]},
      {Plug.Cowboy, scheme: :http, plug: Rest, options: [port: rest_port]},
      {Plug.Cowboy, scheme: :http, plug: Prom, options: [port: prometheus_port]},
      {Plug.Cowboy, scheme: sse_http_scheme, plug: Sse, options: sse_http_config}
    ]

    MetricsPlugExporter.setup()
    SSEStats.setup()

    opts = [strategy: :one_for_one, name: SSEDispatcher.Supervisor]
    Supervisor.start_link(add_cluster_supervisor(children), opts)
  end

  defp ec2_ip_to_nodename(list, _) when is_list(list) do
    [sname, _] = String.split(to_string(node()), "@")

    list
    |> Enum.map(fn ip ->
      :"#{sname}@ip-#{String.replace(ip, ".", "-")}"
    end)
  end

  defp add_cluster_supervisor(children) do
    cond do
      System.get_env("K8S_SELECTOR") && System.get_env("K8S_NAMESPACE") ->
        Logger.info(
          "Starting libcluster with K8S selector: #{System.get_env("K8S_SELECTOR")} in namespace: #{System.get_env("K8S_NAMESPACE")}"
        )

        topologies = [
          k8s: [
            strategy: Cluster.Strategy.Kubernetes,
            config: [
              mode: :ip,
              kubernetes_ip_lookup_mode: :pods,
              kubernetes_node_basename: "sse_dispatcher",
              kubernetes_selector: System.get_env("K8S_SELECTOR"),
              kubernetes_namespace: System.get_env("K8S_NAMESPACE"),
              polling_interval: 10_000
            ]
          ]
        ]

        children ++ [{Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}]

      System.get_env("EPMD_CLUSTER_MEMBERS") ->
        Logger.info(
          "Starting libcluster with EMPD_CLUSTER_MEMBERS: #{System.get_env("EPMD_CLUSTER_MEMBERS")}"
        )

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
        Logger.info(
          "Starting libcluster with EC2_CLUSTER_TAG: #{System.get_env("EC2_CLUSTER_TAG")}"
        )

        topologies = [
          ec2: [
            strategy: ClusterEC2.Strategy.Tags,
            config: [
              ec2_tagname: System.get_env("EC2_CLUSTER_TAG"),
              ec2_tagvalue: System.get_env("EC2_CLUSTER_VALUE"),
              ip_to_nodename: &ec2_ip_to_nodename/2,
              show_debug: true
            ]
          ]
        ]

        children ++ [{Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}]

      true ->
        children
    end
  end
end

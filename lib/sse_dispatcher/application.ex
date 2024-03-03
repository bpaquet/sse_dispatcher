defmodule SSEDispatcher.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: SSEDispatcher.PubSub, options: [adapter: Phoenix.PubSub.PG2, pool_size: 10]},
      {Plug.Cowboy, scheme: :http, plug: Rest, options: [port: 3000]},
      {Plug.Cowboy, scheme: :http, plug: Sse, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: SSEDispatcher.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

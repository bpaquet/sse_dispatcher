defmodule Rest do
  require Logger
  require Node
  import Plug.Conn
  use Plug.Router
  plug(MetricsPlugExporter)

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_file(200, "priv/static/sse.html")
  end

  get "/nodes" do
    nodes = Node.list()

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "Current node: #{node()}\r\nNodes: #{inspect(nodes)}\r\n")
  end

  get "/favicon.ico" do
    conn
    |> send_resp(404, ~c"")
  end

  post "/publish/:topic" do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    :ok = Phoenix.PubSub.broadcast!(SSEDispatcher.PubSub, topic, {:pubsub_message, body})
    Logger.info("Message published on topic: #{topic}")

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "Published #{body} to #{topic}\n")
  end
end

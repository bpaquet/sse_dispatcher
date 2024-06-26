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

  get "/ping" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "ok")
  end

  get "/nodes" do
    nodes = Node.list()

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "Current node: #{node()}\r\nNodes: #{inspect(nodes)}\r\n")
  end

  post "/publish/:topic" do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    message_id = to_string(:os.system_time(:millisecond))

    :ok =
      Phoenix.PubSub.broadcast!(SSEDispatcher.PubSub, topic, {:pubsub_message, message_id, body})

    Logger.debug("Message published on topic: #{topic}")
    SSEStats.inc_msg_received()

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "Published #{body} to #{topic}\n")
  end

  match _ do
    send_resp(conn, 404, "")
  end
end

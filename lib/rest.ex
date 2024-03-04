defmodule Rest do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_file(200, "priv/static/sse.html")
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

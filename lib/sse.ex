defmodule Sse do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug :match
  plug :dispatch

  get "/sse/:topic" do
    conn = put_resp_header(conn, "content-type", "text/event-stream")
    conn = put_resp_header(conn, "Access-Control-Allow-Origin","*")
    conn = send_chunked(conn, 200)

    Phoenix.PubSub.subscribe(SSEDispatcher.PubSub, topic)
    Logger.info("Client subscribed to #{topic}")

    loop(conn)
    conn
  end

  defp loop(conn) do
    receive do
      {:pubsub_message, msg} -> send_message(conn, msg); loop(conn)
      after 300000 -> :timeout
    end
  end

  defp send_message(conn, message) do
    chunk(conn, "event: \"message\"\n\ndata: #{message}\n\n")
  end
end

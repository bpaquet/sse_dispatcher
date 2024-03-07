defmodule Sse do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug(:monitor_sse)

  plug(:match)
  plug(:dispatch)

  get "/sse/:topic" do
    conn = put_resp_header(conn, "content-type", "text/event-stream")
    conn = put_resp_header(conn, "Access-Control-Allow-Origin", "*")
    conn = send_chunked(conn, 200)

    Phoenix.PubSub.subscribe(SSEDispatcher.PubSub, topic)
    Logger.debug("Client subscribed to #{topic}")

    loop(conn)
    Logger.debug("Client disconnected from #{topic}")
    conn
  end

  defp loop(conn) do
    receive do
      {:pubsub_message, msg} ->
        send_message(conn, msg)
        SSEStats.inc_msg_emitted()
        loop(conn)
    after
      300_000 -> :timeout
    end
  end

  defp send_message(conn, message) do
    chunk(conn, "event: \"message\"\n\ndata: #{message}\n\n")
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp monitor_sse(conn, _) do
    {:ok, _pid} = SSEMonitor.start_link(conn)

    conn
  end
end

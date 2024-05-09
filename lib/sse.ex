defmodule Sse do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug(:monitor_sse)

  plug(:match)
  plug(:dispatch)

  get "/ping" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "ok")
  end

  get "/sse/:topic" do
    conn = put_resp_header(conn, "content-type", "text/event-stream")
    conn = put_resp_header(conn, "cache-Control", "no-cache")
    conn = put_resp_header(conn, "connection", "keep-alive")
    conn = put_resp_header(conn, "access-control-allow-origin", "*")
    :ok = Phoenix.PubSub.subscribe(SSEDispatcher.PubSub, topic)
    conn = send_chunked(conn, 200)

    Logger.debug("Client subscribed to #{topic}")

    loop(conn)
    Logger.debug("Client disconnected from #{topic}")
    conn
  end

  defp loop(conn) do
    receive do
      {:pubsub_message, msg} ->
        send_message(conn, msg)
        SSEStats.inc_msg_published()
        loop(conn)
    after
      300_000 -> :timeout
    end
  end

  defp send_message(conn, message) do
    chunk(conn, "data: #{message}\n\n")
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp monitor_sse(conn, _) do
    {:ok, _pid} = SSEMonitor.start_link(conn)

    conn
  end
end

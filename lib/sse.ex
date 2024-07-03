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

    loop(conn, Application.fetch_env!(:sse_dispatcher, :sse_timeout))
    Logger.debug("Client disconnected from #{topic}")
    conn
  end

  defp loop(conn, sse_timeout) do
    receive do
      {:pubsub_message, msg_id, msg} ->
        {:ok, conn} = chunk(conn, "id: #{msg_id}\ndata: #{msg}\n\n")
        SSEStats.inc_msg_published()
        loop(conn, sse_timeout)
    after
      sse_timeout -> :timeout
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp monitor_sse(conn, _) do
    {:ok, _pid} = SSEMonitor.start_link(conn)

    conn
  end
end

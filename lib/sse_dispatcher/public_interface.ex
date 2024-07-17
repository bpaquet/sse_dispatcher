defmodule SseDispatcher.PublicInterface do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug(:monitor_sse)

  plug(SseDispatcher.JwtAuthPlug,
    allowed_algorithm: "RS256",
    jwk_provider: &SseDispatcher.Configuration.public_issuer_jwks/0,
    max_expiration: 60 * 2,
    audience: "public_interface"
  )

  plug(:match)
  plug(:dispatch)

  get "v1/subscribe" do
    case conn.assigns[:jwt_payload] do
      %{"iss" => issuer, "sub" => sub} ->
        topic = "#{issuer}:#{sub}"

        conn =
          conn
          |> put_resp_header("content-type", "text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("connection", "close")
          |> put_resp_header("access-control-allow-origin", "*")
          |> put_resp_header("x-sse-server", to_string(node()))

        :ok = Phoenix.PubSub.subscribe(SSEDispatcher.PubSub, topic)

        conn = send_chunked(conn, 200)

        Logger.debug("Client subscribed to #{topic}")

        conn |> loop(Application.fetch_env!(:sse_dispatcher, :sse_timeout))
        Logger.debug("Client disconnected from #{topic}")
        conn

      _ ->
        conn.resp(:bad_request, "sub claim is missing")
    end
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
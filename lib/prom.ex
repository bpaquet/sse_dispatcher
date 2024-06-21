defmodule Prom do
  use Plug.Router
  plug(MetricsPlugExporter)
  plug(:match)

  get "/ping" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "ok")
  end
end

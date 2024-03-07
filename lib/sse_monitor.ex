defmodule SSEMonitor do
  require Logger
  use GenServer

  def start_link(conn) do
    GenServer.start_link(__MODULE__, conn)
  end

  @impl true
  def init(conn) do
    SSEStats.inc_sse_connections()
    Process.flag(:trap_exit, true)
    {:ok, %{conn: conn}}
  end

  @impl true
  def terminate(:normal, _) do
    SSEStats.dec_sse_connections()
    Logger.debug("SSE Standard end")
  end

  def terminate(reason, _) do
    SSEStats.dec_sse_connections()
    Logger.debug("SSE end: #{reason}")
  end
end

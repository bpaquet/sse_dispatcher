defmodule SSEStats do
  use Prometheus.Metric

  def setup() do
    Gauge.declare(
      name: :sse_current_connections,
      help: "SSE Open connections"
    )

    Counter.declare(
      name: :sse_connections,
      help: "SSE connections"
    )

    Counter.declare(
      name: :sse_msg_received,
      help: "SSE Messages received"
    )

    Counter.declare(
      name: :sse_msg_emitted,
      help: "SSE Messages emitted"
    )
  end

  def inc_sse_connections() do
    Gauge.inc(name: :sse_current_connections)
    Counter.inc(name: :sse_connections)
  end

  def dec_sse_connections() do
    Gauge.dec(name: :sse_current_connections)
  end

  def inc_msg_received() do
    Counter.inc(name: :sse_msg_received)
  end

  def inc_msg_emitted() do
    Counter.inc(name: :sse_msg_emitted)
  end
end

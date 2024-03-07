defmodule LoadTestStats do
  use Prometheus.Metric

  def setup() do
    Gauge.declare(
      name: :user_running,
      help: "User running"
    )

    Counter.declare(
      name: :message_received_ok,
      help: "Message received ok"
    )

    Counter.declare(
      name: :message_received_error,
      help: "Message received error"
    )

    Counter.declare(
      name: :message_published_ok,
      help: "Message published ok"
    )

    Counter.declare(
      name: :message_published_error,
      help: "Message published error"
    )

    Counter.declare(
      name: :user_ok,
      help: "User ok"
    )

    Counter.declare(
      name: :user_error,
      help: "User error"
    )

    Histogram.new(
      name: :propagation_delay,
      buckets: [1, 5, 15, 50, 100, 250, 500, 1000, 5000, :infinity],
      help: "Propagation delay"
    )
  end

  def inc_user_running() do
    Gauge.inc(name: :user_running)
  end

  def dec_user_running() do
    Gauge.dec(name: :user_running)
  end

  def inc_msg_received_ok() do
    Counter.inc(name: :message_received_ok)
  end

  def inc_msg_received_error() do
    Counter.inc(name: :message_received_error)
  end

  def inc_user_ok() do
    Counter.inc(name: :user_ok)
  end

  def inc_user_error() do
    Counter.inc(name: :user_error)
  end

  def inc_msg_published_ok() do
    Counter.inc(name: :message_published_ok)
  end

  def inc_msg_published_error() do
    Counter.inc(name: :message_published_error)
  end

  def observe_propagation(delay) do
    Histogram.observe([name: :propagation_delay], delay)
  end
end

defmodule SSEDispatcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :sse_dispatcher,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def releases do
    [
      sse_dispatcher: [
        include_executables_for: [:unix],
        applications: [sse_dispatcher: :permanent]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SSEDispatcher.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:libcluster, "~> 3.0"},
      {:libcluster_ec2, "~> 0.5"},
      {:prometheus_ex, "~> 3.1"},
      {:prometheus_plugs, "~> 1.0"},
      {:joken, "~> 2.6"},
      {:jason, "~> 1.4"}
    ]
  end
end

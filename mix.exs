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
      {:phoenix_pubsub, "~> 2.0"}
    ]
  end
end

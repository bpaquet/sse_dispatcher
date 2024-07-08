defmodule LoadTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :load_test,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def releases do
    [
      load_test: [
        include_executables_for: [:unix],
        applications: [load_test: :permanent]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {LoadTest.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:prometheus_ex, "~> 3.1"},
      {:prometheus_plugs, "~> 1.0"},
      {:parent, "~> 0.12"},
      {:uuid, "~> 1.1"},
      {:finch, "~> 0.18"}
    ]
  end
end

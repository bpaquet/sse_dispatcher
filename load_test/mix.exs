defmodule LoadTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :load_test,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:uuid, "~> 1.1"},
      {:req, "~> 0.4.0"}
    ]
  end
end

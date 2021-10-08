defmodule Watcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :watcher,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      config_path: "config/config.exs",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:connection, "~> 1.0"},
      {:jason, "~> 1.1"}
    ]
  end
end

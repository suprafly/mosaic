defmodule Mosaic.MixProject do
  use Mix.Project

  def project do
    [
      app: :mosaic,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:hackney, "~> 1.9"},
      {:swoosh, "~> 1.3"},
      {:ecto_sql, "~> 3.6"},
      {:solid, "~> 0.14"},
      # {:gen_smtp, "~> 1.2"},
    ]
  end
end

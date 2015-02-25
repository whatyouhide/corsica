defmodule Corsica.Mixfile do
  use Mix.Project

  def project do
    [app: :corsica,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :cowboy, :plug]]
  end

  defp deps do
    [
      {:cowboy, "~> 1.0", optional: true},
      {:plug, ">= 0.9.0", optional: true},
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.7", only: :docs}
    ]
  end
end

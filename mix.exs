defmodule Corsica.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :corsica,
      version: @version,
      elixir: "~> 1.0",
      deps: deps,
      description: description,
      name: "Corsica",
      source_url: "https://github.com/whatyouhide/corsica",
      package: package,
    ]
  end

  def application do
    [applications: [:logger, :cowboy, :plug]]
  end

  defp description do
    """
    Plug and DSL for efficiently handling or responding to CORS requests
    """
  end

  defp deps do
    [
      {:cowboy, "~> 1.0", optional: true},
      {:plug, ">= 0.9.0", optional: true},
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.7", only: :docs}
    ]
  end

  defp package do
    [
      contributors: "Andrea Leopardi",
      license: ["MIT"],
      links: %{"GitHub" => "https://github.com/whatyouhide/corsica"},
    ]
  end
end

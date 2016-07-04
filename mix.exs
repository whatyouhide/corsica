defmodule Corsica.Mixfile do
  use Mix.Project

  @version "0.5.0"

  def project() do
    [app: :corsica,
     version: @version,
     elixir: "~> 1.0",
     deps: deps(),
     description: description(),
     name: "Corsica",
     source_url: "https://github.com/whatyouhide/corsica",
     package: package()]
  end

  def application() do
    [applications: [:logger, :cowboy, :plug]]
  end

  defp description() do
    """
    Plug-based swiss-army knife for CORS requests.
    """
  end

  defp deps() do
    [{:cowboy, ">= 1.0.0"},
     {:plug, ">= 0.9.0"},
     {:earmark, ">= 0.0.0", only: :docs},
     {:ex_doc, ">= 0.0.0", only: :docs}]
  end

  defp package() do
    [maintainers: ["Andrea Leopardi"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/whatyouhide/corsica"}]
  end
end

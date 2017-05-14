defmodule Corsica.Mixfile do
  use Mix.Project

  @version "0.5.0"

  @description "Plug-based swiss-army knife for CORS requests."

  def project() do
    [app: :corsica,
     version: @version,
     elixir: "~> 1.3",
     deps: deps(),
     description: @description,
     name: "Corsica",
     source_url: "https://github.com/whatyouhide/corsica",
     package: package()]
  end

  def application() do
    [applications: [:logger, :cowboy, :plug]]
  end

  defp deps() do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.0"},
     {:ex_doc, "~> 0.15", only: :dev}]
  end

  defp package() do
    [maintainers: ["Andrea Leopardi"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/whatyouhide/corsica"}]
  end
end

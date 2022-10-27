defmodule Corsica.Mixfile do
  use Mix.Project

  @version "1.3.0"

  @description "Plug-based swiss-army knife for CORS requests."

  def project() do
    [
      app: :corsica,
      version: @version,
      elixir: "~> 1.10",
      deps: deps(),

      # Tests
      test_coverage: [tool: ExCoveralls],

      # Hex
      package: package(),
      description: @description,

      # Docs
      name: "Corsica",
      docs: [
        main: "Corsica",
        source_ref: "v#{@version}",
        source_url: "https://github.com/whatyouhide/corsica",
        extras: ["README.md", "pages/Common issues.md"],
        authors: ["Andrea Leopardi"]
      ]
    ]
  end

  def application() do
    [extra_applications: [:logger]]
  end

  defp deps() do
    [
      {:plug, "~> 1.0"},

      # Dev and test dependencies.
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:ex_doc, "~> 0.15", only: :dev},
      {:stream_data, "~> 0.4", only: [:dev, :test]}
    ]
  end

  defp package() do
    [
      maintainers: ["Andrea Leopardi"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/whatyouhide/corsica",
        "Sponsor" => "https://github.com/sponsors/whatyouhide"
      }
    ]
  end
end

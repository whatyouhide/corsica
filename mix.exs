defmodule Corsica.Mixfile do
  use Mix.Project

  @version "2.1.3"

  @description "Plug-based swiss-army knife for CORS requests."

  def project() do
    [
      app: :corsica,
      version: @version,
      elixir: "~> 1.11",
      deps: deps(),

      # Tests
      test_coverage: [tool: ExCoveralls],

      # Dialyzer
      dialyzer: [
        plt_local_path: "plts",
        plt_core_path: "plts"
      ],

      # Hex
      package: package(),
      description: @description,

      # Docs
      name: "Corsica",
      docs: [
        main: "Corsica",
        source_ref: "v#{@version}",
        source_url: "https://github.com/whatyouhide/corsica",
        extras: ["pages/Common issues.md"],
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
      {:telemetry, "~> 0.4.0 or ~> 1.0"},

      # Dev and test dependencies.
      {:dialyxir, "~> 1.3.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.17", only: :test},
      {:ex_doc, "~> 0.15", only: :dev},
      # TODO: remove this explicitly once ssl_verify_fun fixes its OTP 26 support,
      # or excoveralls stops depending on hackney.
      {:ssl_verify_fun, "~> 1.1", only: :test, override: true, manager: :rebar3},
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

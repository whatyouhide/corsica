defmodule Corsica.Mixfile do
  use Mix.Project

  @version "1.1.2"

  @description "Plug-based swiss-army knife for CORS requests."

  def project() do
    [
      app: :corsica,
      version: @version,
      elixir: "~> 1.3",
      deps: deps(),

      # Hex
      package: package(),
      description: @description,

      # Docs
      name: "Corsica",
      docs: [
        main: "Corsica",
        source_ref: "v#{@version}",
        source_url: "https://github.com/whatyouhide/corsica",
        extras: ["README.md", "pages/Common issues.md"]
      ]
    ]
  end

  def application() do
    [applications: [:logger, :plug]]
  end

  defp deps() do
    deps = [
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.15", only: :dev}
    ]

    if stream_data?() do
      [{:stream_data, "~> 0.4", only: :test}] ++ deps
    else
      deps
    end
  end

  defp package() do
    [
      maintainers: ["Andrea Leopardi"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/whatyouhide/corsica"}
    ]
  end

  defp stream_data?() do
    Version.compare(System.version(), "1.5.0") in [:eq, :gt]
  end
end

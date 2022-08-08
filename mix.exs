defmodule ExPipeline.MixProject do
  use Mix.Project

  @app :ex_pipeline
  @version "0.2.0"
  @source_url "https://github.com/msramos/ex_pipeline"

  def project do
    [
      app: @app,
      version: @version,
      description: "A simple and opinionated pipeline builder",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      mod: {Pipeline.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/ex_pipeline",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md": [filename: "changelog", title: "Changelog"],
        "CODE_OF_CONDUCT.md": [filename: "code_of_conduct", title: "Code of Conduct"],
        LICENSE: [filename: "license", title: "License"],
        NOTICE: [filename: "notice", title: "Notice"]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Marcos Ramos"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end

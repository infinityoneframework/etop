defmodule Etop.MixProject do
  use Mix.Project

  def project do
    [
      app: :etop,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Etop",
      package: package(),
      docs: [
        main: "Etop",
        extras: ["README.md", "LICENSE.md"]
      ],
      description: """
      A Unix top like functionality for Elixir Applications.
      """
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
      # {:cpu_util, path: "../cpu_util"},
      {:cpu_util, "~> 0.1"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22.0", override: true, only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/infinityoneframework/etop"},
      files: ~w(lib README.md mix.exs LICENSE.md)
    ]
  end
end

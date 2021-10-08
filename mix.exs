defmodule Etop.MixProject do
  use Mix.Project

  @source_url "https://github.com/infinityoneframework/etop"
  @version "0.7.0"

  def project do
    [
      app: :etop,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Etop",
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :app_tree
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cpu_util, "~> 0.5"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", override: true, only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false, override: true}
    ]
  end

  defp package do
    [
      description: "A Unix top like functionality for Elixir Applications.",
      maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      files: ~w(lib README.md mix.exs LICENSE.md),
      links: %{"Github" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end

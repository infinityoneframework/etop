defmodule Etop.MixProject do
  use Mix.Project

  def project do
    [
      app: :etop,
      version: "0.7.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_ignore_filters: [~r"/(fixtures|tmp)/"],
      deps: deps(),
      name: "Etop",
      package: package(),
      docs: [
        main: "Etop",
        extras: ["README.md", "LICENSE.md"]
      ],
      dialyzer: [
        plt_add_deps: :app_tree
      ],
      test_coverage: [tool: ExCoveralls],
      description: """
      A Unix top like functionality for Elixir Applications.
      """
    ]
  end

  def cli do
    [
      preferred_envs: [
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
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
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

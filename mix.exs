defmodule Oli.MixProject do
  use Mix.Project

  def project do
    [
      app: :oli,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        "test.coverage": :test,
      ],

      # Docs
      name: "OLI Torus",
      source_url: "https://github.com/Simon-Initiative/oli-torus",
      homepage_url: "http://oli.cmu.edu",
      docs: [
        main: "Oli", # The main page in the docs
        logo: "assets/static/images/oli-icon.png",
        extras: ["README.md", "LICENSE.md", "docs/DEVELOPER.md"]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Oli.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: true},
      {:dialyxir, "~> 0.5.0", only: [:dev], runtime: true},
      {:floki, "~> 0.23.0"},
      {:phoenix, "~> 1.4.16"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:poison, "~> 3.1"},
      {:httpoison, "~> 1.6"},
      {:phoenix_live_dashboard, "~> 0.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.12.1"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:telemetry, "~> 0.4.1"},
      {:telemetry_poller, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:ueberauth, "~> 0.5"},
      {:ueberauth_google, "~> 0.7"},
      {:ueberauth_facebook, "~> 0.8"},
      {:ueberauth_identity, "~> 0.2"},
      {:bcrypt_elixir, "~> 2.2"},
      {:uuid, "~> 1.1" },
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:timex, "~> 3.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "run priv/repo/seeds.exs", "test"],

      # runs tests and produces a coverage report
      "test.coverage": ["ecto.create --quiet", "ecto.migrate", "run priv/repo/seeds.exs", "test --cover"],

      # runs tests in deterministic order, only shows one failure at a time and reruns tests if any changes are made
      "test.watch": ["test.watch --stale --max-failures 1 --trace --seed 0"],
    ]
  end
end

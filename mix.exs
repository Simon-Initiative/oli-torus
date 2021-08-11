defmodule Oli.MixProject do
  use Mix.Project

  def project do
    [
      app: :oli,
      version: "0.12.8",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        test: :test,
        "test.ecto.reset": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.xml": :test
      ],

      # Docs
      name: "OLI Torus",
      source_url: "https://github.com/Simon-Initiative/oli-torus",
      homepage_url: "http://oli.cmu.edu",
      docs: [
        # The main page in the docs
        main: "Oli",
        logo: "assets/static/images/torus-icon.png",
        extras: ["README.md", "LICENSE.md"]
      ],
      releases: [
        oli: [
          include_executables_for: [:unix],
          strip_beams: false,
          applications: [runtime_tools: :permanent]
        ]
      ],
      default_release: :oli
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Oli.Application, []},
      extra_applications: [:logger, :crypto, :public_key, :mnesia, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp elixirc_options(:dev), do: []
  defp elixirc_options(:test), do: []
  defp elixirc_options(_), do: [warnings_as_errors: true]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bamboo, "~> 1.6"},
      {:bamboo_ses, "~> 0.1.0"},
      {:bcrypt_elixir, "~> 2.2"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:csv, "~> 2.3"},
      {:dialyxir, "~> 0.5.0", only: [:dev], runtime: true},
      {:ecto_sql, "~> 3.5.2"},
      {:eflame, "~> 1.0"},
      {:ecto_psql_extras, "~> 0.2"},
      {:ex_aws, "~> 2.1.6"},
      {:ex_aws_s3, "~> 2.0"},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:floki, ">= 0.26.0"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.9"},
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.0"},
      {:joken, "~> 2.2.0"},
      {:jose, "~> 1.10"},
      {:lti_1p3, "~> 0.3.2"},
      {:lti_1p3_ecto_provider, "~> 0.2.2"},
      {:mime, "~> 1.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 0.5", only: :test},
      {:nimble_parsec, "~> 0.5"},
      {:nodejs, "~> 2.0"},
      {:oban, "~> 2.6.1"},
      {:open_api_spex, "~> 3.9"},
      {:phoenix, "~> 1.5.9"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_dashboard, "~> 0.4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.15.7"},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.1"},
      {:poison, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:pow, "~> 1.0.21"},
      {:pow_assent, "~> 0.4.9"},
      {:certifi, "~> 2.4"},
      {:ssl_verify_fun, "~> 1.1"},
      {:premailex, "~> 0.3.0"},
      {:sched_ex, "~> 1.1"},
      {:shortuuid, "~> 2.1"},
      {:telemetry, "~> 0.4.1"},
      {:telemetry_poller, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_metrics_prometheus, "~> 1.0.0"},
      {:timex, "~> 3.5"},
      {:uuid, "~> 1.1"},
      {:xml_builder, "~> 2.1.1"}
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

      # resets the database
      "ecto.reset": ["ecto.drop", "ecto.setup"],

      # resets the database in the :test env
      "test.ecto.reset": ["ecto.reset"]
    ]
  end
end

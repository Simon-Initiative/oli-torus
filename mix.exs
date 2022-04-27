defmodule Oli.MixProject do
  use Mix.Project

  def project do
    [
      app: :oli,
      version: "0.18.4",
      elixir: "~> 1.13.2",
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
      docs: docs(),
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


  defp docs do
    [
      main: "introduction",
      assets: "doc_assets",
      logo: "assets/static/images/torus-icon.png",
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      filter_modules: "ThisModuleDoesNotExist"
    ]
  end

  defp extras do
    [
      "guides/starting/end-user.md",
      "guides/starting/developer.md",
      "guides/starting/self-hosted.md",
      "guides/process/client-coding.md",
      "guides/process/server-coding.md",
      "guides/process/pr-template.md",
      "guides/process/changelog-pr.md",
      "guides/process/deployment.md",
      "guides/process/building.md",
      "guides/design/introduction.md",
      "guides/design/high-level.md",
      "guides/design/publication-model.md",
      "guides/design/attempt.md",
      "guides/design/attempt-handling.md",
      "guides/design/locking.md",
      "guides/design/page-model.md",
      "guides/design/gdpr.md",
      "guides/design/misc.md",
      "guides/activities/overview.md",
      "guides/lti/implementing.md",
      "guides/lti/config.md",
      "guides/ingest/overview.md",
      "guides/ingest/media.md"
    ]
  end

  defp groups_for_extras do
    [
      "Getting started": ~r/guides\/starting\/.?/,
      "Releases": ~r/guides\/releases\/.?/,
      "Process": ~r/guides\/process\/.?/,
      "System design": ~r/guides\/design\/.?/,
      "Activity SDK": ~r/guides\/activities\/.?/,
      "LTI 1.3": ~r/guides\/lti\/.?/,
      "Content ingestion": ~r/guides\/ingest\/.?/
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
      {:appsignal_phoenix, "~> 2.0.0"},
      {:bamboo, "~> 2.2"},
      {:bamboo_ses, "~> 0.3.0"},
      {:bamboo_phoenix, "~> 1.0"},
      {:base32_crockford, "~> 1.0.0"},
      {:bcrypt_elixir, "~> 2.2"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:csv, "~> 2.3"},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 0.5.0", only: [:dev], runtime: true},
      {:ecto_sql, "~> 3.7.0"},
      {:eflame, "~> 1.0"},
      {:ecto_psql_extras, "~> 0.2"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.3"},
      {:ex_aws_lambda, "~> 2.0"},
      {:ex_json_schema, "~> 0.9.1"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:ex_money, "~> 5.0"},
      {:ex_money_sql, "~> 1.0"},
      {:excoveralls, "~> 0.14.4", only: :test},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:floki, ">= 0.30.0"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.17"},
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.3"},
      {:joken, "~> 2.2.0"},
      {:jose, "~> 1.10"},
      {:lti_1p3, "~> 0.4.1"},
      {:lti_1p3_ecto_provider, "~> 0.3.1"},
      {:mime, "~> 1.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 0.5", only: :test},
      {:nimble_parsec, "~> 0.5"},
      {:nodejs, "~> 2.0"},
      {:oban, "~> 2.6.1"},
      {:open_api_spex, "~> 3.9"},
      {:phoenix, "~> 1.5"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.5.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.16.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.1"},
      {:poison, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:pow, "~> 1.0.21"},
      {:pow_assent, "~> 0.4.9"},
      {:react_phoenix, "~> 1.3"},
      {:certifi, "~> 2.7"},
      {:ssl_verify_fun, "~> 1.1"},
      {:surface, "~> 0.5.1"},
      {:premailex, "~> 0.3.0"},
      {:sched_ex, "~> 1.1"},
      {:shortuuid, "~> 2.1"},
      {:sweet_xml, "~> 0.7.1"},
      {:telemetry, "~> 0.4.1"},
      {:telemetry_poller, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_metrics_prometheus, "~> 1.0.0"},
      {:timex, "~> 3.5"},
      {:tzdata, "~> 1.1"},
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

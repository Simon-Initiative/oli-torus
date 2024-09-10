defmodule Oli.MixProject do
  use Mix.Project

  def project do
    [
      app: :oli,
      version: "0.28.8",
      elixir: "~> 1.15.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "test.hound": :hound,
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
      logo: "assets/static/branding/dev/oli_torus_icon.png",
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
      "guides/ingest/media.md",
      "guides/upgrade/dev-env.md",
      "assets/typedocs/modules.md"
    ] ++ list_typedoc_files()
  end

  defp list_typedoc_files() do
    Path.wildcard("assets/typedocs/interfaces/*.md") ++
      Path.wildcard("assets/typedocs/enums/*.md") ++
      Path.wildcard("assets/typedocs/classes/*.md")
  end

  defp groups_for_extras do
    [
      "Getting started": ~r/guides\/starting\/.?/,
      Releases: ~r/guides\/releases\/.?/,
      Process: ~r/guides\/process\/.?/,
      "System design": ~r/guides\/design\/.?/,
      "Activity SDK": ~r/guides\/activities\/.?/,
      "LTI 1.3": ~r/guides\/lti\/.?/,
      "Content ingestion": ~r/guides\/ingest\/.?/,
      "Upgrade integration": ~r/guides\/upgrade\/.?/,
      "Client Side API": ~r/assets\/typedocs\/modules.md/,
      Interfaces: ~r/assets\/typedocs\/interfaces\/.?/,
      Enums: ~r/assets\/typedocs\/enums\/.?/,
      Classes: ~r/assets\/typedocs\/classes\/.?/
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
  defp elixirc_paths(:hound), do: ["lib", "test/support"]
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
      {:appsignal_phoenix, "~> 2.3"},
      {:bamboo, "~> 2.2"},
      {:bamboo_ses, "~> 0.3.0"},
      {:bamboo_phoenix, "~> 1.0"},
      {:base32_crockford, "~> 1.0.0"},
      {:bcrypt_elixir, "~> 2.2"},
      {:briefly, "~> 0.5.0"},
      {:broadway, "~> 1.0.7"},
      {:broadway_dashboard, "~> 0.4.0"},
      {:cachex, "~> 3.5"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:csv, "~> 3.0.5"},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 0.5.0", only: [:dev], runtime: true},
      {:earmark, "~> 1.4"},
      {:ecto_sql, "~> 3.10"},
      {:eflame, "~> 1.0"},
      {:ecto_psql_extras, "~> 0.2"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.3"},
      {:ex_aws_lambda, "~> 2.0"},
      {:ex_cldr, "~> 2.34"},
      {:ex_cldr_plugs, "~> 1.2"},
      {:ex_cldr_calendars, "~> 1.21"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:ex_json_schema, "~> 0.9.1"},
      {:ex_machina, "~> 2.7.0", only: [:hound, :test]},
      {:ex_money, "~> 5.12"},
      {:ex_money_sql, "~> 1.7"},
      {:excoveralls, "~> 0.14.4", only: [:hound, :test]},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:floki, ">= 0.30.0"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.17"},
      {:html_sanitize_ex, "~> 1.4"},
      {:hound, "~> 1.0"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.3"},
      {:joken, "~> 2.2.0"},
      {:jose, "~> 1.10"},
      {:lti_1p3, "~> 0.6.0"},
      {:lti_1p3_ecto_provider, "~> 0.6.0"},
      {:libcluster, "~> 3.3"},
      {:libcluster_ec2, "~> 0.6"},
      {:mime, "~> 1.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:monocle, "~> 0.0.1"},
      {:mox, "~> 0.5", only: [:test, :hound]},
      {:nimble_parsec, "~> 1.2"},
      {:nodejs, "~> 2.0"},
      {:oban, "~> 2.17.2"},
      {:open_api_spex, "~> 3.9"},
      {:openai, "~> 0.5.4"},
      {:pgvector, "~> 0.2.0"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_react, "~> 0.4"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.19.5"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_storybook, "~> 0.5.6"},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.1"},
      {:poison, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:pow, "~> 1.0.31"},
      {:pow_assent, "~> 0.4.17"},
      {:react_phoenix, "~> 1.3"},
      {:certifi, "~> 2.7"},
      {:ssl_verify_fun, "~> 1.1"},
      {:premailex, "~> 0.3.0"},
      {:sched_ex, "~> 1.1"},
      {:shortuuid, "~> 2.1"},
      {:sweet_xml, "~> 0.7.1"},
      {:tailwind, "~> 0.1.9"},
      {:telemetry, "~> 0.4.1"},
      {:telemetry_poller, "~> 0.4"},
      {:telemetry_metrics, "~> 0.4"},
      {:timex, "~> 3.5"},
      {:tzdata, "~> 1.1"},
      {:uuid, "~> 1.1"},
      {:xml_builder, "~> 2.1.1"},
      {:vega_lite, "~> 0.1.9"},
      {:odgn_json_pointer, "~> 3.0.1"}
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
      "test.ecto.reset": ["ecto.reset"],

      # runs the test suite and watches for changes
      "test.watch": ["test.watch --seed 0 --max-failures 1 --include pending --trace"],

      # deploy tailwind assets
      "assets.deploy": ["tailwind default --minify", "tailwind storybook --minify", "phx.digest"]
    ]
  end
end

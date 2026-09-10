defmodule Oli.PreviewQATools.BuildPolicyTest do
  use ExUnit.Case, async: true

  test "Docker builds prod by default and uses the selected environment throughout the release" do
    dockerfile = File.read!("Dockerfile")

    assert dockerfile =~ "ARG MIX_ENV=prod"
    assert dockerfile =~ "RUN mix deps.get --only $MIX_ENV"
    assert dockerfile =~ "COPY config/config.exs config/${MIX_ENV}.exs config/"
    assert dockerfile =~ "/app/_build/${MIX_ENV}/rel/oli"
    refute dockerfile =~ "_build/prod/rel/oli"
  end

  test "both preview image jobs select the preview environment" do
    workflow = File.read!(".github/workflows/build-preview-image.yml")
    production_workflow = File.read!(".github/workflows/package.yml")

    assert length(Regex.scan(~r/^\s+MIX_ENV=preview$/m, workflow)) == 2
    refute production_workflow =~ "MIX_ENV=preview"
  end

  test "preview is treated as production-shaped by compile and runtime branches" do
    mix_project = File.read!("mix.exs")
    endpoint = File.read!("lib/oli_web/endpoint.ex")
    runtime = File.read!("config/runtime.exs")

    assert mix_project =~ "start_permanent: Mix.env() in [:prod, :preview]"
    assert endpoint =~ "gzip: Mix.env() in [:prod, :preview]"
    assert runtime =~ "runtime_env = config_env()"
    refute runtime =~ "System.get_env(\"MIX_ENV\")"
    assert runtime =~ "if runtime_env in [:prod, :preview] do"
  end

  test "preview configuration is standalone and the environment audit remains explicit" do
    preview_config = File.read!("config/preview.exs")
    production_config = File.read!("config/prod.exs")
    shared_config = File.read!("config/config.exs")
    mix_project = File.read!("mix.exs")

    refute preview_config =~ ~s(import_config "prod.exs")
    refute preview_config =~ ~s(import_config "dev.exs")
    refute preview_config =~ "PLAYWRIGHT_SCENARIO_TOKEN"
    refute production_config =~ "PLAYWRIGHT_SCENARIO_TOKEN"
    assert shared_config =~ "enable_playwright_scenarios: false"
    assert shared_config =~ "enable_e2e_mailbox: false"
    assert shared_config =~ "playwright_scenario_token: nil"
    refute Regex.match?(~r/only:\s*(?:\[\s*)?:prod\b/, mix_project)
    assert mix_project =~ ~s(@gleam_erlang_build_root "gleam/build/dev/erlang")
    assert mix_project =~ "compilers: [:phoenix_live_view, :gleam, :gleam_runtime]"
    assert mix_project =~ "elixirc_options: elixirc_options(Mix.env())"
  end

  test "release seeding uses the preview source path only in preview builds" do
    mix_project = File.read!("mix.exs")
    router = File.read!("lib/oli_web/router.ex")
    application = File.read!("lib/oli/application.ex")

    assert mix_project =~
             "defp elixirc_paths(:preview), do: [\"lib\", \"preview/lib\"]"

    refute mix_project =~
             "defp elixirc_paths(:prod), do: [\"lib\", \"preview/lib\"]"

    assert File.regular?("preview/lib/oli/release/preview_qa_tools.ex")
    refute File.dir?("lib/preview_qa_tools/release")

    refute router =~ "PreviewQATools"
    refute application =~ "PreviewQATools.Seed"
    refute application =~ "seed_queue"
  end
end

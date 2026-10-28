defmodule Oli.Seeding.RuntimeTest do
  use ExUnit.Case, async: false

  alias Oli.Seeding.Runtime

  @tag timeout: 120_000
  test "the mix entry point loads runtime configuration in a fresh VM" do
    script = """
    Mix.CLI.main(["seed", "scenarios", "list"])
    "seed-runtime.example" = Application.fetch_env!(:oli, :xapi_host_name)
    """

    {output, status} =
      System.cmd("elixir", ["-e", script],
        env: [{"MIX_ENV", "test"}, {"XAPI_HOST_NAME", "seed-runtime.example"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "oli_torus_getting_started_course"
  end

  @tag timeout: 120_000
  test "the isolated companion runtime can publish and apply a section update" do
    path = "test/scenarios/seeding/publication_update.scenario.yaml"
    assert :ok = Oli.Scenarios.validate_file(path)

    script = """
    Oli.Seeding.Runtime.run(fn ->
      nil = Process.whereis(OliWeb.Endpoint)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo)

      try do
        result = Oli.Scenarios.SeedExecution.execute_file(#{inspect(path)})
        [] = result.errors
        true = Oli.Scenarios.all_verifications_passed?(result)
      after
        Ecto.Adapters.SQL.Sandbox.checkin(Oli.Repo)
      end
    end)
    """

    {output, status} =
      System.cmd("mix", ["run", "--no-start", "-e", script],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
  end

  test "run installs and restores the application role" do
    previous_role = Application.get_env(:oli, :application_role)

    assert :ok =
             Runtime.run(fn ->
               assert Application.get_env(:oli, :application_role) == :seeding
               :ok
             end)

    assert Application.get_env(:oli, :application_role) == previous_role
  end

  test "the companion role starts producers and required data services without server consumers" do
    children = Oli.Application.seeding_children()

    child_modules =
      Enum.map(children, fn
        module when is_atom(module) -> module
        {module, _opts} -> module
        %{start: {module, _function, _args}} -> module
      end)

    assert Oli.Repo in child_modules
    assert Phoenix.PubSub in child_modules
    assert Oban in child_modules
    assert Oli.Delivery.DistributedDepotCoordinator in child_modules
    assert Oli.Delivery.Sections.SectionCache in child_modules

    refute OliWeb.Endpoint in child_modules
    refute Oli.Analytics.XAPI.UploadPipeline in child_modules
    refute Oli.Delivery.DepotWarmer in child_modules
    refute OliWeb.Presence in child_modules

    assert {Oban, oban_config} = Enum.find(children, &match?({Oban, _}, &1))
    assert oban_config[:queues] == []
    assert oban_config[:plugins] == false
  end

  test "both entry points delegate through the dedicated runtime" do
    mix_task = File.read!("seeding/lib/mix/tasks/seed.ex")
    release_wrapper = File.read!("rel/overlays/bin/seed")
    application = File.read!("lib/oli/application.ex")

    assert mix_task =~ "Runtime.run"
    assert release_wrapper =~ "Oli.Seeding.Runtime.main"
    assert release_wrapper =~ "exec ./oli eval"
    assert application =~ "maybe_start_inventory_recovery(:seeding), do: :ok"
    assert application =~ "maybe_log_preview_qa_tools_status(:seeding), do: :ok"
    refute release_wrapper =~ "trap "
  end
end

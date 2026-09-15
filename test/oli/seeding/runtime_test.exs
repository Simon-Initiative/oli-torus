defmodule Oli.Seeding.RuntimeTest do
  use ExUnit.Case, async: false

  alias Oli.Seeding.Runtime

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

defmodule Oli.RuntimeLogOverridesTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.RuntimeLogOverrides
  alias Oli.RuntimeLogOverrides.{DebugLevelRevertWorker, DebugRevertConfig, Registry}

  setup do
    original_level = Logger.level()
    Logger.delete_all_module_levels()
    Registry.reset()

    on_exit(fn ->
      Logger.delete_all_module_levels()
      Registry.reset()
      Logger.configure(level: original_level)
    end)

    :ok
  end

  describe "set_global_level/1" do
    test "schedules a revert job on the local node when setting debug" do
      assert {:ok, :debug} = RuntimeLogOverrides.set_global_level("debug")
      assert Logger.level() == :debug

      timeout_seconds = DebugRevertConfig.timeout_minutes() * 60

      assert_enqueued(
        worker: DebugLevelRevertWorker,
        args: %{
          "node" => Atom.to_string(node()),
          "revert_level" => Atom.to_string(DebugRevertConfig.revert_level())
        },
        scheduled_at: {DateTime.add(DateTime.utc_now(), timeout_seconds), delta: 10}
      )
    end

    test "does not schedule a revert job for non-debug levels" do
      for level <- [:info, "warning", :error] do
        assert {:ok, _level} = RuntimeLogOverrides.set_global_level(level)
      end

      assert Logger.level() == :error
      refute_enqueued(worker: DebugLevelRevertWorker)
    end

    test "restarts the timer when debug is set again" do
      assert {:ok, :debug} = RuntimeLogOverrides.set_global_level(:debug)
      [first_job] = all_enqueued(worker: DebugLevelRevertWorker)

      assert {:ok, :debug} = RuntimeLogOverrides.set_global_level(:debug)

      assert [second_job] = all_enqueued(worker: DebugLevelRevertWorker)
      assert second_job.id != first_job.id
      assert Repo.get!(Oban.Job, first_job.id).state == "cancelled"
    end

    test "rejects invalid levels without changing the level or scheduling a job" do
      Logger.configure(level: :error)

      assert {:error, :invalid_level} = RuntimeLogOverrides.set_global_level("verbose")
      assert {:error, :invalid_level} = RuntimeLogOverrides.set_global_level(:not_a_level)

      assert Logger.level() == :error
      refute_enqueued(worker: DebugLevelRevertWorker)
    end
  end

  describe "set_module_level/2" do
    test "applies a module-level override and lists it" do
      assert {:ok, overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert [%{target: Enum, target_label: "Elixir.Enum", level: :debug}] = overrides.modules
      assert [] = overrides.processes
      assert [{Enum, :debug}] = Logger.get_module_level(Enum)
    end

    test "does not change the global logger level" do
      Logger.configure(level: :error)

      assert {:ok, _overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert Logger.level() == :error
      assert [{Enum, :debug}] = Logger.get_module_level(Enum)
    end

    test "rejects invalid module names" do
      assert {:error, :invalid_module} =
               RuntimeLogOverrides.set_module_level("Not.A.Real.Module", :debug)

      assert [] = RuntimeLogOverrides.list_overrides().modules
    end

    test "rejects invalid levels" do
      assert {:error, :invalid_level} = RuntimeLogOverrides.set_module_level("Enum", "verbose")

      assert [] = RuntimeLogOverrides.list_overrides().modules
      assert [] = Logger.get_module_level(Enum)
    end
  end

  describe "clear_module_level/1" do
    test "clears an applied module-level override" do
      assert {:ok, _overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert {:ok, overrides} = RuntimeLogOverrides.clear_module_level("Enum")

      assert [] = overrides.modules
      assert [] = Logger.get_module_level(Enum)
    end

    test "rejects clearing an invalid module" do
      assert {:error, :invalid_module} = RuntimeLogOverrides.clear_module_level("Not.A.Module")
    end
  end
end

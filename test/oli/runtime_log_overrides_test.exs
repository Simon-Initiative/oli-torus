defmodule Oli.RuntimeLogOverridesTest do
  use ExUnit.Case, async: false

  alias Oli.RuntimeLogOverrides
  alias Oli.RuntimeLogOverrides.Registry

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

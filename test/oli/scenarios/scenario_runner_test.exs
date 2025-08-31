defmodule Oli.Scenarios.ScenarioRunnerTest do
  @moduledoc """
  Universal test runner that discovers and runs all .scenario.yaml files in this directory.
  Each scenario file is run as a separate test case.
  """
  
  use Oli.Scenarios.ScenarioRunner do
    # This block allows adding custom tests in addition to the auto-generated ones
    
    test "verify scenario discovery works" do
      # This test verifies that the scenario discovery mechanism itself works
      test_dir = Path.dirname(__ENV__.file)
      scenarios = Oli.Scenarios.ScenarioRunner.discover_scenarios(test_dir)
      
      # Check that we can discover scenario files (if any exist)
      assert is_list(scenarios)
      
      # Each discovered scenario should have a name and path
      Enum.each(scenarios, fn {name, path} ->
        assert is_binary(name)
        assert is_binary(path)
        assert String.ends_with?(path, ".scenario.yaml")
      end)
    end
  end
end
defmodule Oli.Scenarios.LearningModel.ProficiencyUsageTest do
  use Oli.DataCase, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path "test/scenarios/learning_model/proficiency_usage.scenario.yaml"

  test "naive and LKT-AOA sections expose canonical proficiency through real workflows" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == [], "Scenario errors: #{inspect(result.errors)}"

    failed = Enum.reject(result.verifications, & &1.passed)
    assert failed == [], "Scenario verification failures: #{inspect(failed)}"
  end
end

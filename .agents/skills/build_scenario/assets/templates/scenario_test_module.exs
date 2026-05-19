defmodule MyFeatureScenarioTest do
  use Oli.DataCase, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path "test/scenarios/my_feature/happy_path.scenario.yaml"

  test "happy path scenario executes without errors or failed verifications" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == [], "Scenario errors: #{inspect(result.errors)}"

    failed =
      Enum.filter(result.verifications, fn verification ->
        verification.passed != true
      end)

    assert failed == [], "Scenario verification failures: #{inspect(failed)}"
  end
end

defmodule Oli.Scenarios.LinkedActivitiesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "linked_activities.scenario.yaml")

  test "resolves linked activities across objective descendants and pages" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == [], "Scenario errors: #{inspect(result.errors)}"

    failed_verifications = Enum.reject(result.verifications, & &1.passed)

    assert failed_verifications == [],
           "Scenario verification failures: #{inspect(failed_verifications)}"
  end
end

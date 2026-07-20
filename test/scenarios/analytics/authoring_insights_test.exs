defmodule Oli.Scenarios.Analytics.AuthoringInsightsTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "authoring_insights.scenario.yaml")

  test "aggregates authoring insights across sections and learner outcome patterns" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []

    failed_verifications = Enum.reject(result.verifications, & &1.passed)

    assert failed_verifications == [],
           Enum.map_join(failed_verifications, "\n", & &1.message)

    assert length(result.verifications) == 8
  end
end

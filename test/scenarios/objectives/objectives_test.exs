defmodule Oli.Scenarios.ObjectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "authoring_objectives.scenario.yaml")

  test "objective authoring scenario" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result =
      Scenarios.execute_file(
        @scenario_path,
        RuntimeOpts.build()
      )

    assert result.errors == []

    failed_verifications =
      Enum.filter(result.verifications, fn verification -> !verification.passed end)

    assert failed_verifications == []
  end
end

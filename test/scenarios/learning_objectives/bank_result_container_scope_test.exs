defmodule Oli.Scenarios.LearningObjectives.BankResultContainerScopeTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveTypes.AssertDirective
  alias Oli.Scenarios.Directives.Assert.LearningObjectivesAssertion
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "bank_result_container_scope.scenario.yaml")

  test "unions static and realized bank activity objectives in container scopes" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []
    assert length(result.verifications) == 4
    assert Enum.all?(result.verifications, & &1.passed)
  end

  test "reports an unknown container as a failed verification" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []

    directive = %AssertDirective{
      learning_objectives: %{
        section: "bank_objective_scope_section",
        container: "Missing Unit",
        includes: ["Bank result objective"],
        excludes: []
      }
    }

    assert {:ok, _state, verification} =
             LearningObjectivesAssertion.assert(directive, result.state)

    refute verification.passed
    assert verification.message =~ "Container 'Missing Unit' not found"
  end
end

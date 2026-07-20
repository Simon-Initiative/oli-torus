defmodule Oli.Scenarios.Directives.InsightsAssertionTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveTypes.AssertDirective
  alias Oli.Scenarios.Directives.Assert.InsightsAssertion
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "insights_assertion.scenario.yaml")

  test "asserts activity, page, and objective insights through a real learner workflow" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []
    assert length(result.verifications) == 4
    assert Enum.all?(result.verifications, & &1.passed)
  end

  test "identifies the target and metric when an expected value is wrong" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []

    directive = %AssertDirective{
      insights: %{
        project: "insights_assertion_course",
        sections: ["insights_assertion_section"],
        resource_type: :activity,
        page: nil,
        activity_virtual_id: "insights_question",
        objective: nil,
        part_id: nil,
        expected: %{num_hints: 99},
        exists: true,
        tolerance: 1.0e-6
      }
    }

    assert {:ok, _state, verification} = InsightsAssertion.assert(directive, result.state)
    refute verification.passed
    assert verification.message =~ "Activity 'insights_question' insights mismatch"
    assert verification.message =~ "num_hints expected 99, got 0"
  end

  test "reports unknown section names as failed verifications" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())
    assert result.errors == []

    directive = %AssertDirective{
      insights: %{
        project: "insights_assertion_course",
        sections: ["missing_section"],
        resource_type: :page,
        page: "Answered Practice",
        activity_virtual_id: nil,
        objective: nil,
        part_id: nil,
        expected: %{num_attempts: 1},
        exists: true,
        tolerance: 1.0e-6
      }
    }

    assert {:ok, _state, verification} = InsightsAssertion.assert(directive, result.state)
    refute verification.passed
    assert verification.message =~ "Section 'missing_section' not found"
  end
end

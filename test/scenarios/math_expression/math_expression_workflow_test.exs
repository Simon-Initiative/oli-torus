defmodule Oli.Scenarios.MathExpressionWorkflowTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

  @scenario_path Path.expand("math_expression_workflow.yaml", __DIR__)

  test "math expression workflow publishes and evaluates new and legacy activity content" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result =
      Scenarios.execute_file(
        @scenario_path,
        RuntimeOpts.build()
      )

    assert result.errors == []
    assert Enum.filter(result.verifications, fn verification -> !verification.passed end) == []

    assert_feedback(result, "fraction_full_student", "fraction_math_expression", 2.0, 2.0, [
      "feedback_fraction_simplified"
    ])

    assert_feedback(result, "fraction_partial_student", "fraction_math_expression", 1.0, 2.0, [
      "feedback_fraction_equivalent"
    ])

    assert_feedback(result, "unit_student", "unit_math_expression", 1.0, 1.0, [
      "feedback_speed_convertible"
    ])

    assert_feedback(result, "legacy_student", "legacy_numeric", 1.0, 1.0, [
      "feedback_legacy_numeric_correct"
    ])

    assert_feedback(result, "legacy_student", "legacy_math", 1.0, 1.0, [
      "feedback_legacy_math_correct"
    ])
  end

  defp assert_feedback(result, student, activity_virtual_id, score, out_of, feedback_ids) do
    key = {student, "math_expression_section", "Math Expression Practice", activity_virtual_id}

    assert [%FeedbackAction{} = action] = Map.fetch!(result.state.activity_evaluations, key)

    assert action.score == score
    assert action.out_of == out_of
    assert action.feedback.id in feedback_ids
  end
end

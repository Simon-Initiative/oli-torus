defmodule Oli.Scenarios.MathExpressionWorkflowTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

  @scenario_path Path.expand("math_expression_workflow.yaml", __DIR__)
  @first_class_scenario_path Path.expand("first_class_math_expression_workflow.yaml", __DIR__)

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

  test "first-class YAML math expression workflow publishes and evaluates short answer and multi-input content" do
    assert :ok = Scenarios.validate_file(@first_class_scenario_path)

    result =
      Scenarios.execute_file(
        @first_class_scenario_path,
        RuntimeOpts.build()
      )

    assert result.errors == []
    assert Enum.filter(result.verifications, fn verification -> !verification.passed end) == []

    assert_feedback(
      result,
      "fraction_yaml_full_student",
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_fraction",
      2.0,
      2.0,
      ["feedback_yaml_fraction_simplified"]
    )

    assert_feedback(
      result,
      "fraction_yaml_partial_student",
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_fraction",
      1.0,
      2.0,
      ["feedback_yaml_fraction_equivalent"]
    )

    assert_feedback(
      result,
      "wrong_units_yaml_student",
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_wrong_units",
      1.0,
      2.0,
      ["feedback_yaml_units_wrong"]
    )

    assert_feedback(
      result,
      "missing_unit_yaml_student",
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_wrong_units",
      1.0,
      2.0,
      ["feedback_yaml_units_missing"]
    )

    assert_feedback(
      result,
      "domain_yaml_student",
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_domain",
      1.0,
      1.0,
      ["feedback_yaml_domain_correct"]
    )

    assert_multi_feedback(result, "multi_yaml_student", [
      {"speed", 1.0, 1.0, "feedback_yaml_speed_correct"},
      {"energy", 1.0, 1.0, "feedback_yaml_energy_correct"}
    ])
  end

  defp assert_feedback(result, student, activity_virtual_id, score, out_of, feedback_ids) do
    key = {student, "math_expression_section", "Math Expression Practice", activity_virtual_id}

    assert [%FeedbackAction{} = action] = Map.fetch!(result.state.activity_evaluations, key)

    assert action.score == score
    assert action.out_of == out_of
    assert action.feedback.id in feedback_ids
  end

  defp assert_feedback(
         result,
         student,
         section,
         page,
         activity_virtual_id,
         score,
         out_of,
         feedback_ids
       ) do
    key = {student, section, page, activity_virtual_id}

    assert [%FeedbackAction{} = action] = Map.fetch!(result.state.activity_evaluations, key)

    assert action.score == score
    assert action.out_of == out_of
    assert action.feedback.id in feedback_ids
  end

  defp assert_multi_feedback(result, student, expected) do
    key = {
      student,
      "first_class_math_expression_section",
      "Math Expression YAML Practice",
      "yaml_multi_units"
    }

    actions = Map.fetch!(result.state.activity_evaluations, key)

    actual =
      actions
      |> Enum.map(&{&1.part_id, &1.score, &1.out_of, &1.feedback.id})
      |> Enum.sort()

    assert actual == Enum.sort(expected)
  end
end

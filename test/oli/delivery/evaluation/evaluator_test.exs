defmodule Oli.Delivery.Evaluation.EvaluatorTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Evaluation.Evaluator
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

  defp feedback(id) do
    %{"id" => id, "content" => %{"model" => []}}
  end

  defp response(id, rule, score, correct \\ false) do
    %{
      "id" => id,
      "rule" => rule,
      "score" => score,
      "correct" => correct,
      "feedback" => feedback("f-#{id}")
    }
  end

  defp eval_context(input) do
    %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      activity_attempt_guid: "activity-guid",
      part_attempt_number: 1,
      part_attempt_guid: "part-guid",
      page_id: 1,
      input: input
    }
  end

  defp parse_part!(part_map) do
    {:ok, part} = Part.parse(part_map)
    part
  end

  test "correct response is boosted to max targeted score" do
    part =
      parse_part!(%{
        "id" => "1",
        "responses" => [
          response("r1", "input like {a}", 1, true),
          response("r2", "input like {b}", 4, false),
          response("r3", "input like {.*}", 0, false)
        ]
      })

    {:ok, %FeedbackAction{score: score, out_of: out_of}} =
      Evaluator.evaluate(part, eval_context("a"), 1.0)

    assert score == 4.0
    assert out_of == 4.0
  end

  test "correct response is boosted to part outOf when part outOf exceeds max response score" do
    part =
      parse_part!(%{
        "id" => "1",
        "outOf" => 6,
        "responses" => [
          response("r1", "input like {a}", 2, true),
          response("r2", "input like {b}", 4, false),
          response("r3", "input like {.*}", 0, false)
        ]
      })

    {:ok, %FeedbackAction{score: score, out_of: out_of}} =
      Evaluator.evaluate(part, eval_context("a"), 1.0)

    assert score == 6.0
    assert out_of == 6.0
  end

  test "correct response score remains when already at or above max targeted score" do
    part =
      parse_part!(%{
        "id" => "1",
        "responses" => [
          response("r1", "input like {a}", 5, true),
          response("r2", "input like {b}", 4, false),
          response("r3", "input like {.*}", 0, false)
        ]
      })

    {:ok, %FeedbackAction{score: score, out_of: out_of}} =
      Evaluator.evaluate(part, eval_context("a"), 1.0)

    assert score == 5.0
    assert out_of == 5.0
  end

  test "does not boost when correct response is marked as targeted" do
    part =
      parse_part!(%{
        "id" => "1",
        "targetedResponseIds" => ["r1"],
        "responses" => [
          response("r1", "input like {a}", 1, true),
          response("r2", "input like {b}", 4, false),
          response("r3", "input like {.*}", 0, false)
        ]
      })

    {:ok, %FeedbackAction{score: score, out_of: out_of}} =
      Evaluator.evaluate(part, eval_context("a"), 1.0)

    assert score == 1.0
    assert out_of == 4.0
  end
end

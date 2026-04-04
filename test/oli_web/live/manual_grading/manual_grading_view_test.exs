defmodule OliWeb.ManualGrading.ManualGradingViewTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias OliWeb.ManualGrading.ScoreFeedback
  alias OliWeb.ManualGrading.ManualGradingView

  test "manual_scoring_ready?/2 requires score and feedback for every manual part" do
    part_attempts = [
      %PartAttempt{
        attempt_guid: "manual-1",
        grading_approach: :manual
      },
      %PartAttempt{
        attempt_guid: "manual-2",
        grading_approach: :manual
      },
      %PartAttempt{
        attempt_guid: "auto-1",
        grading_approach: :automatic
      }
    ]

    refute ManualGradingView.manual_scoring_ready?(part_attempts, %{
             "manual-1" => %ScoreFeedback{score: 1.0, feedback: "ok", out_of: 1.0}
           })

    refute ManualGradingView.manual_scoring_ready?(part_attempts, %{
             "manual-1" => %ScoreFeedback{score: 1.0, feedback: "ok", out_of: 1.0},
             "manual-2" => %ScoreFeedback{score: 1.0, feedback: "   ", out_of: 1.0}
           })

    assert ManualGradingView.manual_scoring_ready?(part_attempts, %{
             "manual-1" => %ScoreFeedback{score: 1.0, feedback: "ok", out_of: 1.0},
             "manual-2" => %ScoreFeedback{score: 0.5, feedback: "partial", out_of: 1.0}
           })
  end

  test "manual_scoring_ready?/2 is false when there are no manual parts" do
    refute ManualGradingView.manual_scoring_ready?(
             [
               %PartAttempt{
                 attempt_guid: "auto-1",
                 grading_approach: :automatic
               }
             ],
             %{}
           )
  end

  test "ordered_part_attempts/2 brings the selected part to the front without reordering the rest" do
    part_attempts = [
      %PartAttempt{attempt_guid: "part-1"},
      %PartAttempt{attempt_guid: "part-2"},
      %PartAttempt{attempt_guid: "part-3"}
    ]

    assert Enum.map(
             ManualGradingView.ordered_part_attempts(part_attempts, "part-2"),
             & &1.attempt_guid
           ) ==
             ["part-2", "part-1", "part-3"]

    assert Enum.map(
             ManualGradingView.ordered_part_attempts(part_attempts, "missing"),
             & &1.attempt_guid
           ) ==
             ["part-1", "part-2", "part-3"]
  end
end

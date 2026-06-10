defmodule Oli.Delivery.Attempts.FeedbackTextTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.FeedbackText
  import Oli.Factory

  describe "manual_feedback_texts_by_resource_attempt_guid/1" do
    test "fetches only manual feedback text keyed by resource attempt guid" do
      first_attempt = insert(:resource_attempt)
      second_attempt = insert(:resource_attempt)

      first_activity_attempt =
        insert(:activity_attempt, resource_attempt: first_attempt)

      second_activity_attempt =
        insert(:activity_attempt, resource_attempt: second_attempt)

      insert(:part_attempt,
        activity_attempt: first_activity_attempt,
        grading_approach: :manual,
        feedback: feedback("Needs more detail.")
      )

      insert(:part_attempt,
        activity_attempt: first_activity_attempt,
        grading_approach: :automatic,
        feedback: feedback("Automatic feedback should not be shown.")
      )

      insert(:part_attempt,
        activity_attempt: second_activity_attempt,
        grading_approach: :manual,
        feedback: nil
      )

      assert FeedbackText.manual_feedback_texts_by_resource_attempt_guid([
               first_attempt,
               second_attempt
             ]) == %{
               first_attempt.attempt_guid => ["Needs more detail."],
               second_attempt.attempt_guid => []
             }
    end

    test "includes feedback from multiple manual parts for the same resource attempt" do
      resource_attempt = insert(:resource_attempt)
      activity_attempt = insert(:activity_attempt, resource_attempt: resource_attempt)

      insert(:part_attempt,
        activity_attempt: activity_attempt,
        grading_approach: :manual,
        feedback: feedback("First manual note.")
      )

      insert(:part_attempt,
        activity_attempt: activity_attempt,
        grading_approach: :manual,
        feedback: feedback("Second manual note.")
      )

      assert FeedbackText.manual_feedback_texts_by_resource_attempt_guid([resource_attempt]) == %{
               resource_attempt.attempt_guid => ["First manual note.", "Second manual note."]
             }
    end
  end

  defp feedback(text) do
    %{
      "content" => [
        %{
          "children" => [%{"text" => text}],
          "id" => "feedback",
          "type" => "p"
        }
      ]
    }
  end
end

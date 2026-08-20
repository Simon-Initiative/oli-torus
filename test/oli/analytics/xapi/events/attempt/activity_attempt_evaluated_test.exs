defmodule Oli.Analytics.XAPI.Events.Attempt.ActivityAttemptEvaluatedTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.XAPI.Events.Attempt.{
    ActivityAttemptEvaluated,
    PageAttemptEvaluated,
    PartAttemptEvaluated
  }

  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Delivery.Attempts.Core.ActivityAttempt

  test "adds pseudonymous enrollment identity to evaluated activity context" do
    context = %Context{
      user_id: 11,
      host_name: "https://example.edu",
      section_id: 22,
      project_id: 33,
      publication_id: 44,
      enrollment_id: 55
    }

    activity_attempt = %ActivityAttempt{
      attempt_guid: "activity-attempt-guid",
      attempt_number: 2,
      score: 3.0,
      out_of: 4.0,
      date_evaluated: ~U[2026-08-19 12:00:00Z],
      resource_id: 66,
      revision_id: 77
    }

    page_attempt = %{
      attempt_guid: "page-attempt-guid",
      attempt_number: 1,
      resource_id: 88
    }

    statement = ActivityAttemptEvaluated.new(context, activity_attempt, page_attempt)
    extensions = get_in(statement, ["context", "extensions"])

    assert extensions["http://oli.cmu.edu/extensions/enrollment_id"] == 55

    assert extensions["http://oli.cmu.edu/extensions/activity_attempt_guid"] ==
             "activity-attempt-guid"

    assert extensions["http://oli.cmu.edu/extensions/page_attempt_guid"] == "page-attempt-guid"
    assert statement["timestamp"] == ~U[2026-08-19 12:00:00Z]
    assert get_in(statement, ["result", "score", "raw"]) == 3.0
    assert get_in(statement, ["result", "score", "max"]) == 4.0
    refute Map.has_key?(extensions, "http://oli.cmu.edu/extensions/user_id")

    other_section_statement =
      ActivityAttemptEvaluated.new(
        %Context{context | section_id: 99, enrollment_id: 100},
        activity_attempt,
        page_attempt
      )

    assert get_in(other_section_statement, [
             "context",
             "extensions",
             "http://oli.cmu.edu/extensions/enrollment_id"
           ]) == 100
  end

  test "adds enrollment identity to evaluated page and part contexts" do
    context = %Context{
      user_id: 11,
      host_name: "https://example.edu",
      section_id: 22,
      project_id: 33,
      publication_id: 44,
      enrollment_id: 55
    }

    page_attempt = %{
      attempt_guid: "page-attempt-guid",
      attempt_number: 1,
      resource_id: 88,
      score: 1.0,
      out_of: 2.0,
      date_evaluated: ~U[2026-08-19 12:00:00Z]
    }

    activity_attempt = %{attempt_guid: "activity-guid", attempt_number: 1}

    part_attempt = %{
      activity_revision: %{objectives: [], resource_id: 66, id: 77},
      activity_attempt: activity_attempt,
      attempt_guid: "part-guid",
      attempt_number: 1,
      hints: [],
      response: "answer",
      score: 1.0,
      out_of: 1.0,
      feedback: nil,
      date_evaluated: ~U[2026-08-19 12:00:00Z],
      part_id: "part-1",
      datashop_session_id: "session-1"
    }

    for statement <- [
          PageAttemptEvaluated.new(context, page_attempt),
          PartAttemptEvaluated.new(context, part_attempt, page_attempt)
        ] do
      extensions = get_in(statement, ["context", "extensions"])
      assert extensions["http://oli.cmu.edu/extensions/enrollment_id"] == 55
      refute Map.has_key?(extensions, "http://oli.cmu.edu/extensions/user_id")
    end
  end
end

defmodule Oli.Delivery.Page.AssignmentTermsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Page.AssignmentTerms
  alias Oli.Delivery.Settings.Combined
  alias OliWeb.Common.SessionContext

  @ctx %SessionContext{
    browser_timezone: "Etc/UTC",
    local_tz: "Etc/UTC",
    author: nil,
    user: nil,
    is_liveview: false,
    section: nil
  }

  describe "build/4" do
    test "builds score-at-end cards for scheduled multi-attempt assignments" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            scoring_strategy_id: 2,
            start_date: ~U[2026-05-01 00:00:00Z],
            end_date: ~U[2026-07-01 00:00:00Z],
            scheduling_type: :due_by,
            time_limit: 15,
            late_start: :allow,
            late_submit: :allow
          },
          [],
          @ctx
        )

      assert terms.schedule.available =~ "May 1, 2026"
      assert terms.schedule.due =~ "July 1, 2026"
      assert terms.schedule.late_submission.state == :default

      assert terms.schedule.late_submission.text ==
               "Submissions past the due date will be marked late"

      assert terms.time_limit.duration == "15 minutes"
      assert terms.time_limit.text == "15 minutes to complete once you begin"

      assert terms.scoring.mode == :score_at_end
      assert terms.scoring.strategy == :best
      assert terms.scoring.text == "Your final score will be your best attempt out of 5"

      assert terms.attempts.title == "Attempts"
      assert terms.attempts.value == "0/5"
      assert terms.attempts.cta_label == "Begin 1st Attempt"
      assert terms.attempts.cta_enabled?
      assert terms.attempts.past_attempts == []
    end

    test "includes past attempts and advances score-at-end CTA ordinal" do
      attempt =
        %ResourceAttempt{
          revision: %{graded: true},
          score: 15,
          out_of: 20,
          date_submitted: ~U[2026-03-30 12:00:00Z],
          lifecycle_state: :evaluated,
          attempt_guid: "attempt-guid"
        }

      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            scoring_strategy_id: 2
          },
          [attempt],
          @ctx
        )

      assert terms.attempts.value == "1/5"
      assert terms.attempts.cta_label == "Begin 2nd Attempt"

      assert [
               %{
                 number: 1,
                 score: 15,
                 out_of: 20,
                 submitted_at: submitted_at,
                 lifecycle_state: :evaluated,
                 attempt_guid: "attempt-guid"
               }
             ] = terms.attempts.past_attempts

      assert submitted_at =~ "Mar 30, 2026"
    end

    test "builds SAYG attempts-per-question and scoring copy" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: false,
            max_attempts: 5,
            scoring_strategy_id: 2,
            replacement_strategy: :none
          },
          [],
          @ctx
        )

      assert terms.scoring.mode == :score_as_you_go

      assert terms.scoring.text ==
               "Score as you go: Each question is submitted and scored individually. You have 5 attempts per question. Your best score for each question will count toward your final score."

      assert terms.attempts.title == "Attempts per question"
      assert terms.attempts.value == "5"
      assert terms.attempts.description == "Each question can be attempted up to 5 times."
      assert terms.attempts.cta_label == "Begin Assignment"
    end

    test "builds SAYG replacement copy when dynamic replacement is enabled" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: false,
            max_attempts: 5,
            scoring_strategy_id: 2,
            replacement_strategy: :dynamic
          },
          [],
          @ctx
        )

      assert terms.scoring.text =~ "Resetting may give you a new version of the question."

      assert terms.attempts.description ==
               "Each question can be attempted up to 5 times. Resetting may replace the question."
    end

    test "marks late submission as warning after due date passes" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            end_date: DateTime.utc_now() |> DateTime.add(-1, :day),
            scheduling_type: :due_by,
            late_start: :allow,
            late_submit: :allow
          },
          [],
          @ctx
        )

      assert terms.schedule.late_submission.state == :warning

      assert terms.schedule.late_submission.text ==
               "The due date has passed. If you start a new attempt, it will be marked late."
    end

    test "hides optional cards when no relevant information exists" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 1,
            start_date: nil,
            end_date: nil,
            time_limit: 0,
            late_start: :disallow,
            late_submit: :disallow
          },
          [],
          @ctx,
          allow_attempt?: false
        )

      assert terms.schedule == nil
      assert terms.time_limit == nil
      assert terms.scoring == nil
      assert terms.attempts.cta_enabled? == false
    end
  end
end

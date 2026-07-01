defmodule Oli.Delivery.Page.AssignmentTermsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Page.AssignmentTerms
  alias Oli.Delivery.Settings.Combined

  describe "build/3" do
    test "builds score-at-end cards for scheduled multi-attempt assignments" do
      start_date = DateTime.utc_now() |> DateTime.add(1, :day)
      end_date = DateTime.utc_now() |> DateTime.add(30, :day)

      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            scoring_strategy_id: 2,
            start_date: start_date,
            end_date: end_date,
            scheduling_type: :due_by,
            time_limit: 15,
            late_start: :allow,
            late_submit: :allow
          },
          []
        )

      assert terms.schedule.available == start_date
      assert terms.schedule.due == end_date
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
          [attempt]
        )

      assert terms.attempts.value == "1/5"
      assert terms.attempts.cta_label == "Begin 2nd Attempt"

      assert [
               %{
                 number: 1,
                 score: 15,
                 out_of: 20,
                 submitted_at: ~U[2026-03-30 12:00:00Z],
                 lifecycle_state: :evaluated,
                 attempt_guid: "attempt-guid",
                 feedback_texts: []
               }
             ] = terms.attempts.past_attempts
    end

    test "includes compact feedback text without retaining the attempt struct" do
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
          feedback_texts_by_attempt_guid: %{"attempt-guid" => ["Needs more detail."]}
        )

      assert [
               %{
                 attempt_guid: "attempt-guid",
                 feedback_texts: ["Needs more detail."]
               } = past_attempt
             ] = terms.attempts.past_attempts

      refute Map.has_key?(past_attempt, :resource_attempt)
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
          []
        )

      assert terms.scoring.mode == :score_as_you_go

      assert terms.scoring.text ==
               "Score as you go: Each question is submitted and scored individually. You have 5 attempts per question. Your best score for each question will count toward your final score."

      assert terms.attempts.title == "Attempts per question"
      assert terms.attempts.value == "5"
      assert terms.attempts.description == "Each question can be attempted up to 5 times."
      assert terms.attempts.cta_label == "Begin Assignment"
    end

    test "uses attempt history copy for SAYG pages with existing graded attempts" do
      attempt =
        %ResourceAttempt{
          revision: %{graded: true},
          score: 5,
          out_of: 10,
          date_submitted: ~U[2026-03-30 12:00:00Z],
          lifecycle_state: :submitted,
          attempt_guid: "attempt-guid"
        }

      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: false,
            max_attempts: 3,
            scoring_strategy_id: 2,
            replacement_strategy: :none
          },
          [attempt]
        )

      assert terms.attempts.title == "Attempts"
      assert terms.attempts.value == "1/3"
      assert terms.attempts.description == nil
      assert terms.attempts.cta_label == "Begin 2nd Attempt"
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
          []
        )

      assert terms.scoring.text =~ "Resetting may give you a new version of the question."

      assert terms.attempts.description ==
               "Each question can be attempted up to 5 times. Resetting may replace the question."
    end

    test "does not build a schedule card for unscheduled assignments when the section has scheduled resources" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            start_date: nil,
            end_date: nil,
            time_limit: 0,
            late_start: :allow,
            late_submit: :allow
          },
          [],
          has_scheduled_resources?: true
        )

      assert terms.schedule == nil
    end

    test "does not build a schedule card for unscheduled assignments when the section has no scheduled resources" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            start_date: nil,
            end_date: nil,
            time_limit: 0,
            late_start: :allow,
            late_submit: :allow
          },
          []
        )

      assert terms.schedule == nil
    end

    test "uses time-limit late copy for read-by assignments and no late card without a time limit" do
      terms_with_time_limit =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            end_date: ~U[2026-07-01 00:00:00Z],
            scheduling_type: :read_by,
            time_limit: 10,
            late_start: :allow,
            late_submit: :allow
          },
          []
        )

      assert terms_with_time_limit.schedule.late_submission.text ==
               "Submissions past the time limit will be marked late"

      terms_without_time_limit =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            end_date: ~U[2026-07-01 00:00:00Z],
            scheduling_type: :read_by,
            time_limit: 0,
            late_start: :allow,
            late_submit: :allow
          },
          []
        )

      assert terms_without_time_limit.schedule.late_submission == nil
    end

    test "does not show late submission copy when late submissions are disallowed" do
      due_by_terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            end_date: ~U[2026-07-01 00:00:00Z],
            scheduling_type: :due_by,
            time_limit: 0,
            late_start: :allow,
            late_submit: :disallow
          },
          []
        )

      assert due_by_terms.schedule.late_submission == nil

      read_by_terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            end_date: ~U[2026-07-01 00:00:00Z],
            scheduling_type: :read_by,
            time_limit: 10,
            late_start: :allow,
            late_submit: :disallow
          },
          []
        )

      assert read_by_terms.schedule.late_submission == nil
    end

    test "builds unlimited attempt copy for score-at-end and SAYG assignments" do
      attempts = [
        %ResourceAttempt{revision: %{graded: true}},
        %ResourceAttempt{revision: %{graded: true}}
      ]

      score_at_end_terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 0,
            scoring_strategy_id: 2
          },
          attempts
        )

      assert score_at_end_terms.attempts.title == "Attempts"
      assert score_at_end_terms.attempts.value == "2/unlimited"
      assert score_at_end_terms.attempts.cta_label == "Begin 3rd Attempt"
      assert score_at_end_terms.scoring.text == "Your final score will be your best attempt"

      sayg_terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: false,
            max_attempts: 0,
            scoring_strategy_id: 1,
            replacement_strategy: :none
          },
          []
        )

      assert sayg_terms.attempts.title == "Attempts per question"
      assert sayg_terms.attempts.value == "Unlimited"

      assert sayg_terms.attempts.description ==
               "Each question can be attempted an unlimited number of times."

      assert sayg_terms.scoring.text =~ "You have unlimited attempts per question."
    end

    test "uses meaningful copy for total score-at-end strategy" do
      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            scoring_strategy_id: 4
          },
          []
        )

      assert terms.scoring.text == "Your final score will be your total score across attempts"
    end

    test "filters ungraded historical attempts out of the attempts card" do
      graded_attempt = %ResourceAttempt{
        revision: %{graded: true},
        score: 10,
        out_of: 10,
        date_submitted: ~U[2026-03-30 12:00:00Z],
        lifecycle_state: :evaluated,
        attempt_guid: "graded-attempt"
      }

      ungraded_attempt = %ResourceAttempt{
        revision: %{graded: false},
        score: 0,
        out_of: 0,
        date_submitted: ~U[2026-03-31 12:00:00Z],
        lifecycle_state: :evaluated,
        attempt_guid: "ungraded-attempt"
      }

      missing_revision_attempt = %ResourceAttempt{
        score: 5,
        out_of: 10,
        date_submitted: ~U[2026-04-01 12:00:00Z],
        lifecycle_state: :evaluated,
        attempt_guid: "missing-revision-attempt"
      }

      terms =
        AssignmentTerms.build(
          %Combined{
            batch_scoring: true,
            max_attempts: 5,
            scoring_strategy_id: 2
          },
          [graded_attempt, ungraded_attempt, missing_revision_attempt]
        )

      assert terms.attempts.value == "1/5"
      assert [%{attempt_guid: "graded-attempt"}] = terms.attempts.past_attempts
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
          []
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
          allow_attempt?: false
        )

      assert terms.schedule == nil
      assert terms.time_limit == nil
      assert terms.scoring == nil
      assert terms.attempts.cta_enabled? == false
    end
  end
end

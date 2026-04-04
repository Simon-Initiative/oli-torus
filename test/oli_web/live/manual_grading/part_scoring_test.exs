defmodule OliWeb.ManualGrading.PartScoringTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias OliWeb.ManualGrading.PartScoring

  test "renders manual scoring controls when part scoring state is temporarily missing" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-1",
          lifecycle_state: :submitted,
          grading_approach: :manual,
          out_of: 10.0
        },
        part_scoring: nil,
        input_type_label: "Input Text",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        feedback_required: true,
        selected: true,
        selected_changed: "select_part"
      })

    assert html =~ "Input Text"
    assert html =~ "Enter feedback for the student..."
    assert html =~ "Score"
    assert html =~ "Out Of"
    assert html =~ "Required"
    assert html =~ "Feedback is required before you can apply grading for this activity."
    assert html =~ "Add feedback for this input to enable Apply Score and Feedback."
    assert html =~ "value=\"10.0\""
    assert html =~ "md:grid-cols-[14rem_minmax(0,1fr)]"
    assert html =~ "Selected Input"
    assert html =~ "phx-click=\"select_part\""
    assert html =~ "cursor-pointer"
    assert html =~ "aria-pressed=\"true\""
    assert html =~ "for=\"score_attempt-guid-1\""
    assert html =~ "for=\"out_of_attempt-guid-1\""
    assert html =~ "for=\"feedback_attempt-guid-1\""
    assert html =~ "step=\"any\""
    assert html =~ "required"
    assert html =~ "aria-required=\"true\""
    assert html =~ "aria-invalid=\"true\""
    assert html =~ "feedback_help_attempt-guid-1"
    assert html =~ "feedback_error_attempt-guid-1"
  end

  test "renders automatic parts as read-only even while submitted" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-2",
          lifecycle_state: :submitted,
          grading_approach: :automatic,
          score: 4.0,
          out_of: 5.0,
          feedback: %{
            "content" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "System feedback"}]
              }
            ]
          }
        },
        part_scoring: nil,
        input_type_label: "Dropdown",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        selected: false,
        selected_changed: "select_part"
      })

    assert html =~ "Dropdown"
    assert html =~ "Score: 4.0 / 5.0"
    assert html =~ "Automatically Graded"
    assert html =~ "Select Input"
    refute html =~ "System feedback"
    refute html =~ "Enter feedback for the student..."
    refute html =~ "phx-hook=\"TextInputListener\""
  end

  test "renders evaluated manual parts with graded pill in collapsed header" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-5",
          lifecycle_state: :evaluated,
          grading_approach: :manual,
          score: 0.8,
          out_of: 1.0,
          feedback: nil
        },
        part_scoring: nil,
        input_type_label: "Input Text",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        selected: false,
        selected_changed: "select_part"
      })

    assert html =~ "Manual Grading"
    assert html =~ "Input Text"
    assert html =~ "Scored"
    assert html =~ "Score: 0.8 / 1.0"
    refute html =~ "No feedback provided"
  end

  test "falls back to generic message for automatic parts without feedback" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-3",
          lifecycle_state: :submitted,
          grading_approach: :automatic,
          score: 1.0,
          out_of: 1.0,
          feedback: nil
        },
        part_scoring: nil,
        input_type_label: "Formula",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        selected: false,
        selected_changed: "select_part"
      })

    assert html =~ "Formula"
    refute html =~ "This part was automatically graded by the system"
  end

  test "renders unselected manual parts in collapsed mode" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-4",
          lifecycle_state: :submitted,
          grading_approach: :manual,
          out_of: 1.0
        },
        part_scoring: nil,
        input_type_label: "Text Slider",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        feedback_required: false,
        selected: false,
        selected_changed: "select_part"
      })

    assert html =~ "Text Slider"
    assert html =~ "Select Input"
    refute html =~ "Enter feedback for the student..."
    refute html =~ "Score"
    refute html =~ "Out Of"
  end

  test "renders graded pill for unsaved completed manual grading" do
    html =
      render_component(&PartScoring.render/1, %{
        part_attempt: %PartAttempt{
          attempt_guid: "attempt-guid-6",
          lifecycle_state: :submitted,
          grading_approach: :manual,
          out_of: 1.0
        },
        part_scoring: %OliWeb.ManualGrading.ScoreFeedback{
          score: 0.75,
          feedback: "Looks good",
          out_of: 1.0
        },
        input_type_label: "Input Number",
        feedback_changed: "feedback_changed",
        score_changed: "score_changed",
        feedback_required: false,
        selected: false,
        selected_changed: "select_part"
      })

    assert html =~ "Input Number"
    assert html =~ "Scored"
  end
end

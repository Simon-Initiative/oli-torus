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
        selected: true,
        selected_changed: "select_part"
      })

    assert html =~ "Input Text"
    assert html =~ "Enter feedback for the student..."
    assert html =~ "Score"
    assert html =~ "Out Of"
    assert html =~ "value=\"10.0\""
    assert html =~ "md:grid-cols-[14rem_minmax(0,1fr)]"
    assert html =~ "Selected Input"
    assert html =~ "phx-click=\"select_part\""
    assert html =~ "cursor-pointer"
    assert html =~ "for=\"score_attempt-guid-1\""
    assert html =~ "for=\"out_of_attempt-guid-1\""
    assert html =~ "for=\"feedback_attempt-guid-1\""
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
    assert html =~ "System feedback"
    assert html =~ "Score: 4.0 / 5.0"
    assert html =~ "Automatically Graded"
    assert html =~ "Click to inspect"
    refute html =~ "Enter feedback for the student..."
    refute html =~ "phx-hook=\"TextInputListener\""
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
    assert html =~ "This part was automatically graded by the system"
  end
end

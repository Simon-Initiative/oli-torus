defmodule OliWeb.ManualGrading.SelectedSubmissionTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.ManualGrading.SelectedSubmission

  test "renders placeholder when no part is selected" do
    html = render_component(&SelectedSubmission.render/1, %{submission: nil})

    assert html =~ "Student Submission"
    assert html =~ "Select an input below"
  end

  test "renders choice based submission details" do
    html =
      render_component(&SelectedSubmission.render/1, %{
        submission: %{
          title: "Screen Input 1",
          subtitle: "Dropdown • Part ID: janus-dropdown-1",
          score: "1.0 / 1.0",
          response_view: %{
            kind: :choice_list,
            prompt: "Choose an option",
            description: "Dropdown response",
            selected_summary: "Option 2",
            choices: [
              %{label: "Option 1", selected: false},
              %{label: "Option 2", selected: true}
            ]
          }
        }
      })

    assert html =~ "Choose an option"
    assert html =~ "Option 2"
    assert html =~ "Selected Response"
  end

  test "renders fill blanks response details" do
    html =
      render_component(&SelectedSubmission.render/1, %{
        submission: %{
          title: "Screen Input 2",
          subtitle: "Fill Blanks • Part ID: janus-fill-blanks-1",
          score: "Pending / 3.0",
          response_view: %{
            kind: :fill_blanks,
            prompt: "Complete the blanks",
            description: "Blank-by-blank learner response",
            blanks: [
              %{label: "blank1", value: "Mercury", meta: "Correct"},
              %{label: "blank2", value: "Venus", meta: nil}
            ]
          }
        }
      })

    assert html =~ "Complete the blanks"
    assert html =~ "Mercury"
    assert html =~ "Correct"
    assert html =~ "Venus"
  end

  test "renders value based response details" do
    html =
      render_component(&SelectedSubmission.render/1, %{
        submission: %{
          title: "Screen Input 3",
          subtitle: "Slider • Part ID: janus-slider-1",
          score: "2.0 / 2.0",
          response_view: %{
            kind: :value,
            prompt: "Rate confidence",
            description: "Slider",
            value: "4",
            details: [
              %{label: "Range", value: "0 to 5"},
              %{label: "Selected Label", value: "Confident"}
            ]
          }
        }
      })

    assert html =~ "Rate confidence"
    assert html =~ "Range"
    assert html =~ "0 to 5"
    assert html =~ "Confident"
  end

  test "renders prose based response details" do
    html =
      render_component(&SelectedSubmission.render/1, %{
        submission: %{
          title: "Question Response",
          subtitle: "Short Answer • Part ID: 1",
          score: "Pending / 1.0",
          response_view: %{
            kind: :prose,
            prompt: "Explain your reasoning",
            description: "Short Answer",
            value: "Lorem ipsum dolor sit amet.",
            details: [
              %{label: "Files", value: "No files uploaded"}
            ]
          }
        }
      })

    assert html =~ "Explain your reasoning"
    assert html =~ "Lorem ipsum dolor sit amet."
    assert html =~ "Files"
    assert html =~ "No files uploaded"
    refute html =~ "text-2xl"
  end
end

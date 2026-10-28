defmodule OliWeb.Components.Delivery.WarningThresholdRenderersTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ContentTableModel
  alias OliWeb.Components.Delivery.Pages.PagesTableModel
  alias OliWeb.Delivery.Pages.ActivitiesTableModel
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias OliWeb.Delivery.StudentDashboard.Components.Helpers

  test "activity percent correct shows a red warning only below its existing threshold" do
    low = render_column(&ActivitiesTableModel.render_avg_score_column/3, %{avg_score: 0.39})
    boundary = render_column(&ActivitiesTableModel.render_avg_score_column/3, %{avg_score: 0.40})
    absent = render_column(&ActivitiesTableModel.render_avg_score_column/3, %{avg_score: nil})

    assert low =~ "text-red-600 font-bold"
    assert low =~ ~s(aria-label="Percent correct below threshold")
    assert low =~ "stroke-current"
    refute boundary =~ ~s(role="img")
    assert absent =~ "-"
    refute absent =~ ~s(role="img")
  end

  test "page average score and student progress use their existing danger treatment" do
    score = render_column(&PagesTableModel.render_avg_score_column/3, %{avg_score: 0.39})

    progress =
      render_column(&PagesTableModel.render_students_completion_column/3, %{
        avg_score: 0.75,
        students_completion: 0.39
      })

    assert score =~ "text-Text-text-danger"
    assert score =~ ~s(aria-label="Average score below threshold")
    assert progress =~ "text-Text-text-danger"
    assert progress =~ ~s(aria-label="Student progress below threshold")
  end

  test "content and enrollment progress warnings inherit their existing red colors" do
    content =
      render_column(&ContentTableModel.render_student_completion/3, %{progress: 0.49})

    enrollment =
      render_column(&EnrollmentsTableModel.render_progress_column/3, %{progress: 0.49})

    assert content =~ "text-[#CE2C31] dark:text-[#FF8787]"
    assert content =~ ~s(aria-label="Student progress below threshold")
    assert enrollment =~ "text-Text-text-danger"
    assert enrollment =~ ~s(aria-label="Low student progress")
  end

  test "enrollment progress uses the exclusive Low Progress boundary" do
    below_boundary =
      render_column(&EnrollmentsTableModel.render_progress_column/3, %{progress: 0.499})

    boundary =
      render_column(&EnrollmentsTableModel.render_progress_column/3, %{progress: 0.50})

    assert below_boundary =~ "text-Text-text-danger"
    assert below_boundary =~ ~s(aria-label="Low student progress")
    refute boundary =~ "text-Text-text-danger"
    refute boundary =~ ~s(role="img")
  end

  test "student details warn independently for low average score and course completion" do
    html =
      render_component(&Helpers.student_details/1, %{
        student: %{
          picture: nil,
          email: "student@example.com",
          avg_score: 0.25,
          progress: 0.40
        },
        survey_responses: []
      })

    assert html =~ ~s(aria-label="Average score below threshold")
    assert html =~ ~s(aria-label="Course completion below threshold")
    assert length(Regex.scan(~r/stroke-current/, html)) == 2
  end

  defp render_column(renderer, row) do
    render_component(fn assigns -> renderer.(assigns, row, nil) end)
  end
end

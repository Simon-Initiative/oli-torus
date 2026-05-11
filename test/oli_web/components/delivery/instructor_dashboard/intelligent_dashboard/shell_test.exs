defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.ShellTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Shell

  test "renders summary above the dashboard sections using projection-backed assigns" do
    html =
      render_component(Shell,
        id: "learning_dashboard_shell",
        containers: {0, []},
        dashboard_scope: "course",
        params: %{},
        section: %{slug: "demo-section", title: "Demo Section"},
        dashboard_visible_sections: [],
        dashboard: %{
          summary_projection: %{
            cards: [
              %{
                id: :average_student_progress,
                label: "Average Student Progress",
                value_text: "65%",
                tooltip_key: :average_student_progress
              }
            ],
            recommendation: %{
              label: "AI Recommendation",
              status: :beginning_course,
              body: "Students have not started yet."
            },
            layout: %{visible_card_count: 1, card_grid_class: "grid-cols-1"},
            scope_label: "Entire Course"
          },
          summary_projection_status: %{status: :ready}
        },
        summary_tile_state: %{regenerate_in_flight?: false},
        progress_tile_state: %{},
        student_support_tile_state: %{}
      )

    assert html =~ ~s(id="learning-dashboard-summary-tile")
    assert html =~ ~s(id="learning-dashboard-sections")
    assert html =~ ~s(id="intelligent-dashboard-download-form")
    assert String.contains?(html, "Average Student Progress")
    assert String.contains?(html, "Students have not started yet.")

    assert elem(:binary.match(html, "learning-dashboard-summary-tile"), 0) <
             elem(:binary.match(html, "learning-dashboard-sections"), 0)
  end
end

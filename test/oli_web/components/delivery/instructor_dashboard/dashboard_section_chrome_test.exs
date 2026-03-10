defmodule OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChromeTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  use Phoenix.Component

  alias OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome

  describe "section/1" do
    test "renders toggle and move controls with canonical section metadata" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <DashboardSectionChrome.section
              id="learning-dashboard-engagement-group"
              section_id="engagement"
              title="Engagement"
              expanded={true}
            >
              Inner tile content
            </DashboardSectionChrome.section>
            """
          end,
          %{}
        )

      assert html =~ ~s(phx-hook="DashboardSectionChrome")
      assert html =~ ~s(data-dashboard-section-id="engagement")
      assert html =~ ~s(data-reorder-event="dashboard_sections_reordered")
      assert html =~ ~s(id="learning-dashboard-engagement-group-toggle")
      assert html =~ ~s(aria-expanded="true")
      assert html =~ ~s(aria-controls="learning-dashboard-engagement-group-content")
      assert html =~ ~s(phx-click="dashboard_section_toggled")
      assert html =~ ~s(phx-value-section_id="engagement")
      assert html =~ ~s(phx-value-expanded="false")
      assert html =~ ~s(id="learning-dashboard-engagement-group-move")
      assert html =~ ~s(aria-label="Move")
      assert html =~ ~s(title="Move")
      assert html =~ "Inner tile content"
    end

    test "omits content body when collapsed and flips the toggle payload" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <DashboardSectionChrome.section
              id="learning-dashboard-content-group"
              section_id="content"
              title="Content"
              expanded={false}
            >
              Hidden content
            </DashboardSectionChrome.section>
            """
          end,
          %{}
        )

      assert html =~ ~s(aria-expanded="false")
      assert html =~ ~s(phx-value-expanded="true")
      refute html =~ ~s(id="learning-dashboard-content-group-content")
      refute html =~ "Hidden content"
    end
  end
end

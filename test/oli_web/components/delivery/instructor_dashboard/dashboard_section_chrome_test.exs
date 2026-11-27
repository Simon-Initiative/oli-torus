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
      assert html =~ ~s(data-section-title="Engagement")
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
      assert html =~ ~s(data-section-live-region)
      assert html =~ ~s(aria-live="polite")
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
      assert html =~ ~s(aria-controls="learning-dashboard-content-group-content")

      assert [_content] =
               html
               |> Floki.parse_fragment!()
               |> Floki.find("#learning-dashboard-content-group-content.hidden")

      refute html =~ "Hidden content"
    end

    test "omits the move handle when reordering is unavailable" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <DashboardSectionChrome.section
              id="learning-dashboard-engagement-group"
              section_id="engagement"
              title="Engagement"
              expanded={true}
              show_move_handle={false}
            >
              Inner tile content
            </DashboardSectionChrome.section>
            """
          end,
          %{}
        )

      refute html =~ ~s(id="learning-dashboard-engagement-group-move")
      refute html =~ ~s(data-section-handle)
    end

    test "hides the expand and collapse arrow from screen readers but keeps the toggle's name" do
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

      [toggle] =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("#learning-dashboard-engagement-group-toggle")

      assert [arrow] = Floki.find(toggle, "svg")
      assert Floki.attribute(arrow, "aria-hidden") == ["true"]
      assert Floki.text(Floki.find(toggle, ".sr-only")) == "Collapse Engagement section"
    end

    test "hides the move handle's dots from screen readers but keeps the handle's name" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <DashboardSectionChrome.section
              id="learning-dashboard-engagement-group"
              section_id="engagement"
              title="Engagement"
              move_label="Move Engagement card"
            >
              Inner tile content
            </DashboardSectionChrome.section>
            """
          end,
          %{}
        )

      [handle] =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("#learning-dashboard-engagement-group-move")

      assert Floki.attribute(handle, "aria-label") == ["Move Engagement card"]
      assert [dots] = Floki.find(handle, "svg")
      assert Floki.attribute(dots, "aria-hidden") == ["true"]
    end
  end
end

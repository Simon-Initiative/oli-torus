defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControlTest do
  use OliWeb.ConnCase, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControl

  describe "coverage_issues_control/1" do
    test "renders the label and count in the inactive state by default" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageIssuesControl.coverage_issues_control count={3} />
          """
        end)

      assert html =~ "Coverage Issues"
      assert html =~ ~r/>\s*3\s*</
      assert html =~ "bg-Background-bg-primary"
      assert html =~ "bg-Fill-fill-danger"
      assert html =~ "text-Table-text-danger"
      assert html =~ ~s(aria-pressed="false")
      assert html =~ ~s(<span aria-hidden="true">)
    end

    test "switches to the active/pressed styling when active is true" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageIssuesControl.coverage_issues_control count={1} active={true} />
          """
        end)

      assert html =~ ~s(aria-pressed="true")
      # Button switches to the danger-fill background. The badge matches
      # Figma's verified light-mode look exactly (red fill, white text) and
      # only overrides dark mode explicitly (unverified in Figma, but kept
      # WCAG-compliant) — see the moduledoc for why.
      refute html =~ "bg-Background-bg-primary"
      assert html =~ "bg-Fill-fill-danger"
      assert html =~ "bg-[#CE2C31]"
      assert html =~ "text-white"
      assert html =~ "dark:bg-[#33181A]"
      assert html =~ "dark:text-[#EEEBF5]"
    end

    test "still renders a zero count rather than hiding the badge" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageIssuesControl.coverage_issues_control count={0} />
          """
        end)

      assert html =~ ~r/>\s*0\s*</
    end

    test "renders a multi-digit count without a fixed width that would clip it" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageIssuesControl.coverage_issues_control count={128} />
          """
        end)

      # min-w (not a fixed w-) plus rounded-full lets the badge grow into a
      # pill for multi-digit counts instead of clipping to a circle sized
      # for one digit.
      assert html =~ ~r/>\s*128\s*</
      assert html =~ "min-w-[19px]"
      refute html =~ ~r/\sw-\[19px\]/
    end

    test "wires the supplied click handler" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageIssuesControl.coverage_issues_control count={1} click="apply_filter" />
          """
        end)

      assert html =~ ~s(phx-click="apply_filter")
    end
  end
end

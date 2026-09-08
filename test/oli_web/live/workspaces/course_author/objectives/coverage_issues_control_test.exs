defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControlTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControl

  describe "coverage_issues_control/1" do
    test "renders the label and count in the inactive state" do
      html = render_control()

      assert html =~ "Coverage Issues"
      assert html =~ ~r/>\s*3\s*</
      assert html =~ "bg-Background-bg-primary"
      assert html =~ "bg-Fill-fill-danger"
      assert html =~ "text-Table-text-danger"
      assert html =~ ~s(aria-pressed="false")
      assert html =~ ~s(<span aria-hidden="true">)
    end

    test "switches to the active/pressed styling when active is true" do
      html = render_control(%{count: 1, active: true})

      assert html =~ ~s(aria-pressed="true")
      refute html =~ "bg-Background-bg-primary"
      assert html =~ "bg-Fill-fill-danger"
      assert html =~ "bg-[#CE2C31]"
      assert html =~ "text-white"
      assert html =~ "dark:bg-[#33181A]"
      assert html =~ "dark:text-[#EEEBF5]"
    end

    test "still renders a zero count rather than hiding the badge" do
      html = render_control(%{count: 0})

      assert html =~ ~r/>\s*0\s*</
    end

    test "renders a multi-digit count without a fixed width that would clip it" do
      html = render_control(%{count: 128})

      assert html =~ ~r/>\s*128\s*</
      assert html =~ "min-w-[19px]"
      refute html =~ ~r/\sw-\[19px\]/
    end

    test "wires the supplied click handler" do
      html = render_control(%{count: 1, click: "apply_filter"})

      assert html =~ ~s(phx-click="apply_filter")
    end
  end

  defp render_control(overrides \\ %{}) do
    assigns = Map.merge(%{count: 3, active: false, click: nil, id: nil}, overrides)
    render_component(&CoverageIssuesControl.coverage_issues_control/1, assigns)
  end
end

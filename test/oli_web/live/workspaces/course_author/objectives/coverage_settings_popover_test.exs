defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopoverTest do
  use OliWeb.ConnCase, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopover

  describe "coverage_settings_popover/1" do
    test "renders both threshold rows with their current values" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageSettingsPopover.coverage_settings_popover
            id="coverage-settings-popover"
            trigger_id="coverage-settings-trigger"
            formative_threshold={3}
            summative_threshold={5}
          />
          """
        end)

      assert html =~ "Minimum formative"
      assert html =~ "Minimum summative"
      assert html =~ ~s(phx-click="decrement_coverage_formative_threshold")
      assert html =~ ~s(phx-click="increment_coverage_formative_threshold")
      assert html =~ ~s(phx-click="decrement_coverage_summative_threshold")
      assert html =~ ~s(phx-click="increment_coverage_summative_threshold")
      assert html =~ ~r/>\s*3\s*</
      assert html =~ ~r/>\s*5\s*</
    end

    test "disables the decrement button at zero but not the increment button" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageSettingsPopover.coverage_settings_popover
            id="coverage-settings-popover"
            trigger_id="coverage-settings-trigger"
            formative_threshold={0}
            summative_threshold={3}
          />
          """
        end)

      assert html =~ ~s(phx-click="decrement_coverage_formative_threshold" disabled)
      refute html =~ ~s(phx-click="increment_coverage_formative_threshold" disabled)
    end

    test "shows the explanatory copy and keeps Learn more hidden for MER-5919" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageSettingsPopover.coverage_settings_popover
            id="coverage-settings-popover"
            trigger_id="coverage-settings-trigger"
            formative_threshold={3}
            summative_threshold={3}
          />
          """
        end)

      assert html =~ "objectives are flagged as coverage issues"
      assert html =~ ~s(phx-click="restore_default_coverage_thresholds")
      assert html =~ "Restore default"
      assert html =~ ~s(id="coverage-settings-learn-more")
      assert html =~ ~r/id="coverage-settings-learn-more"\s+class="[^"]*\bhidden\b/
      assert html =~ "Learn more"
      # MER-5919 supplies the knowledge-base URL and makes this visible.
      refute html =~ ~r/<a[^>]*>\s*Learn more/
    end

    test "renders centered below its trigger at the Figma width" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageSettingsPopover.coverage_settings_popover
            id="coverage-settings-popover"
            trigger_id="coverage-settings-trigger"
            formative_threshold={3}
            summative_threshold={3}
          />
          """
        end)

      assert html =~ "left-1/2"
      assert html =~ "-translate-x-1/2"
      assert html =~ "w-[298px]"
    end

    test "starts hidden, leaving dismissal to the caller's wrapper" do
      html =
        render_component(fn assigns ->
          ~H"""
          <CoverageSettingsPopover.coverage_settings_popover
            id="coverage-settings-popover"
            trigger_id="coverage-settings-trigger"
            formative_threshold={3}
            summative_threshold={3}
          />
          """
        end)

      assert html =~ "hidden"
      refute html =~ "phx-click-away"
    end
  end

  describe "toggle_js/2 and close_js/2" do
    test "both target the popover and its trigger" do
      toggle = CoverageSettingsPopover.toggle_js("pop", "trig").ops |> Jason.encode!()

      assert toggle =~ ~s("toggle")
      assert toggle =~ ~s("#pop")
      assert toggle =~ ~s("#trig")
      assert toggle =~ ~s(["aria-expanded","true","false"])

      close = CoverageSettingsPopover.close_js("pop", "trig").ops |> Jason.encode!()

      assert close =~ ~s("hide")
      assert close =~ ~s("#pop")
      assert close =~ ~s("set_attr")
      assert close =~ ~s(["aria-expanded","false"])
    end
  end
end

defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopoverTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopover

  describe "coverage_settings_popover/1" do
    test "renders both threshold rows with their current values" do
      html = render_popover(%{summative_threshold: 5})

      assert html =~ "Minimum formative"
      assert html =~ "Minimum summative"
      assert html =~ ~s(phx-click="decrement_coverage_formative_threshold")
      assert html =~ ~s(phx-click="increment_coverage_formative_threshold")
      assert html =~ ~s(phx-click="decrement_coverage_summative_threshold")
      assert html =~ ~s(phx-click="increment_coverage_summative_threshold")
      assert html =~ "close_coverage_settings"
      assert html =~ ~s(phx-key="Escape")
      assert html =~ ~r/>\s*3\s*</
      assert html =~ ~r/>\s*5\s*</
    end

    test "disables the decrement button at zero but not the increment button" do
      html = render_popover(%{formative_threshold: 0})

      assert html =~ ~r/phx-click="decrement_coverage_formative_threshold"[^>]*disabled/
      refute html =~ ~s(phx-click="increment_coverage_formative_threshold" disabled)
    end

    test "shows the explanatory copy and keeps Learn more hidden and non-interactive" do
      html = render_popover()

      assert html =~ "objectives are flagged as coverage issues"
      assert html =~ ~s(phx-click="restore_default_coverage_thresholds")
      assert html =~ "Restore default"
      assert html =~ ~s(id="coverage-settings-learn-more")
      assert html =~ ~r/id="coverage-settings-learn-more"\s+class="[^"]*\bhidden\b/
      assert html =~ "Learn more"
      refute html =~ ~r/<a[^>]*>\s*Learn more/
    end

    test "renders centered below its trigger at the Figma width" do
      html = render_popover()

      assert html =~ "left-1/2"
      assert html =~ "-translate-x-1/2"
      assert html =~ "w-[298px]"
    end

    test "is rendered only while open and handles Escape within the popover" do
      html = render_popover()

      assert html =~ "hidden"
      assert html =~ ~s(phx-key="Escape")
      assert html =~ "phx-window-keydown"
      assert html =~ "motion-reduce:duration-0"
      assert html =~ ~s(id="coverage-settings-popover-focus-wrap")
      refute html =~ "phx-click-away"
    end
  end

  describe "open_js/2" do
    test "opening records the trigger then moves focus inside" do
      open = CoverageSettingsPopover.open_js("pop", "trig").ops |> Jason.encode!()

      assert open =~ ~s("show")
      assert open =~ ~s("#pop")
      assert open =~ ~s("#trig")
      assert open =~ ~s("push_focus")
      assert open =~ ~s("focus_first")
    end
  end

  describe "close_js/0" do
    test "restores focus before asking the LiveView to close" do
      close = CoverageSettingsPopover.close_js().ops |> Jason.encode!()

      assert close =~ ~s("pop_focus")
      assert close =~ ~s("close_coverage_settings")
    end
  end

  defp render_popover(overrides \\ %{}) do
    assigns =
      Map.merge(
        %{
          id: "coverage-settings-popover",
          trigger_id: "coverage-settings-trigger",
          formative_threshold: 3,
          summative_threshold: 3
        },
        overrides
      )

    render_component(&CoverageSettingsPopover.coverage_settings_popover/1, assigns)
  end
end

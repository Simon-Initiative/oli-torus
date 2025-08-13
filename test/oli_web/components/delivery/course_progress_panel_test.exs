defmodule OliWeb.Components.Delivery.CourseProgressPanelTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.CourseProgressPanel

  describe "progress_panel/1" do
    test "renders progress panel with course progress" do
      assigns = %{progress: 75}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      assert html =~ "Course Progress"
      assert html =~ "Overall Course Progress"
      assert html =~ "75"
    end

    test "renders progress panel with 0 progress" do
      assigns = %{progress: 0}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      assert html =~ "Course Progress"
      assert html =~ "Overall Course Progress"
      assert html =~ "0"
    end

    test "renders progress panel with 100 progress" do
      assigns = %{progress: 100}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      assert html =~ "Course Progress"
      assert html =~ "Overall Course Progress"
      assert html =~ "100"
    end

    test "renders progress panel with dark mode classes" do
      assigns = %{progress: 50}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      # Check for dark mode classes
      assert html =~ "dark:bg-gray-800"
      assert html =~ "dark:border-gray-700"
    end

    test "renders progress bar with percentage text and styling" do
      assigns = %{progress: 25}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      # Should include progress bar component with percentage text
      assert html =~ "25%"
      # Should include progress bar styling classes
      assert html =~ "rounded-full"
      assert html =~ "bg-gray-200"
      assert html =~ "bg-green-600"
    end

    test "renders with correct styling classes" do
      assigns = %{progress: 60}

      html = render_component(&CourseProgressPanel.progress_panel/1, assigns)

      # Check for expected CSS classes
      assert html =~ "bg-white"
      assert html =~ "shadow"
      assert html =~ "p-4"
      assert html =~ "border-t"
      assert html =~ "font-semibold"
    end
  end
end

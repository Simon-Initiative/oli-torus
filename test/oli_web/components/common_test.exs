defmodule OliWeb.Components.CommonTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Common

  describe "progress_bar/1" do
    test "renders valid progressbar semantics and accepts a data selector" do
      html =
        render_component(&Common.progress_bar/1, %{
          percent: 42,
          aria_label: "Course progress",
          show_halo: true,
          rest: %{"data-role" => "course progress bar"}
        })

      assert html =~ ~s(role="progressbar")
      assert html =~ ~s(aria-label="Course progress")
      assert html =~ ~s(aria-valuemin="0")
      assert html =~ ~s(aria-valuemax="100")
      assert html =~ ~s(aria-valuenow="42")
      assert html =~ ~s(data-role="course progress bar")
      assert html =~ ~s(data-role="progress")
      assert html =~ ~s(aria-hidden="true")
    end
  end
end

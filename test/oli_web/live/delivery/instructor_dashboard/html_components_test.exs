defmodule OliWeb.Delivery.InstructorDashboard.HTMLComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents

  describe "render_label/1 info tooltip accessibility" do
    test "is keyboard-focusable and exposes the tooltip via aria-describedby when info_tooltip is set" do
      html =
        render_component(&HTMLComponents.render_label/1,
          title: "Student Proficiency",
          info_tooltip: "Some tooltip content"
        )

      assert html =~ ~s(tabindex="0")
      assert html =~ ~s(role="button")
      assert html =~ ~s(role="tooltip")
      assert html =~ ~s(id="info-tooltip-student-proficiency")
      assert html =~ ~s(aria-describedby="info-tooltip-student-proficiency")
      assert html =~ "group-focus-within:flex"
    end

    test "does not add tabindex or aria-describedby when there is no tooltip" do
      html = render_component(&HTMLComponents.render_label/1, title: "Linked Activities")

      refute html =~ "tabindex"
      refute html =~ "aria-describedby"
    end
  end
end

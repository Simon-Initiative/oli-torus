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
      refute html =~ ~s(role="button")
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

    test "an explicit :id overrides the title-derived tooltip id to avoid collisions" do
      html =
        render_component(&HTMLComponents.render_label/1,
          title: "Confidence",
          info_tooltip: "Some tooltip content",
          id: "confidence-tooltip-42"
        )

      assert html =~ ~s(id="confidence-tooltip-42")
      assert html =~ ~s(aria-describedby="confidence-tooltip-42")
      refute html =~ "info-tooltip-confidence"
    end
  end
end

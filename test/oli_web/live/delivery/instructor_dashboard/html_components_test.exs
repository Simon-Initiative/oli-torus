defmodule OliWeb.Delivery.InstructorDashboard.HTMLComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents

  describe "info_tooltip/1" do
    test "is keyboard-focusable and exposes the tooltip via aria-describedby" do
      html =
        render_component(&HTMLComponents.info_tooltip/1,
          title: "Avg Score",
          info_tooltip: "Some tooltip content"
        )

      assert html =~ ~s(tabindex="0")
      refute html =~ ~s(role="button")
      assert html =~ ~s(role="tooltip")
      assert html =~ ~s(id="info-tooltip-avg-score")
      assert html =~ ~s(aria-describedby="info-tooltip-avg-score")
      assert html =~ "group-focus-within:flex"
      refute html =~ "<button"
    end

    test "with a label, the trigger is a <button> named by it" do
      html =
        render_component(&HTMLComponents.info_tooltip/1,
          title: "Student Proficiency",
          info_tooltip: "Some tooltip content",
          label: "About Student Proficiency"
        )

      assert [button] = html |> Floki.parse_fragment!() |> Floki.find("button")
      assert Floki.attribute(button, "type") == ["button"]
      assert Floki.attribute(button, "aria-label") == ["About Student Proficiency"]
      assert Floki.attribute(button, "aria-describedby") == ["info-tooltip-student-proficiency"]
    end

    test "an explicit :id overrides the title-derived tooltip id to avoid collisions" do
      html =
        render_component(&HTMLComponents.info_tooltip/1,
          title: "Confidence",
          info_tooltip: "Some tooltip content",
          id: "confidence-tooltip-42"
        )

      assert html =~ ~s(id="confidence-tooltip-42")
      assert html =~ ~s(aria-describedby="confidence-tooltip-42")
      refute html =~ "info-tooltip-confidence"
    end
  end

  describe "student_progress_info/1" do
    test "is a named button that toggles its tooltip on activation" do
      html = render_component(&HTMLComponents.student_progress_info/1, %{})

      assert [button] =
               html |> Floki.parse_fragment!() |> Floki.find("#student_progress_tooltip_trigger")

      assert Floki.attribute(button, "type") == ["button"]
      assert Floki.attribute(button, "aria-label") == ["About Student Progress"]
      assert Floki.attribute(button, "aria-describedby") == ["student_progress_tooltip"]

      assert Floki.attribute(button, "phx-click") == [
               ~s([["toggle",{"display":"flex","to":"#student_progress_tooltip"}]])
             ]
    end
  end
end

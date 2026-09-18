defmodule OliWeb.NewCourse.NewCourseTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Publishing.Publications.Publication

  describe "wizard left-panel step copy" do
    setup [:instructor_conn]

    test "renders the agreed title and description for all three steps (AC-014)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "h4", "Select your source materials")

      assert has_element?(
               view,
               "p",
               "Select the source of materials to base your course curriculum on."
             )

      assert has_element?(view, "h4", "Name your course")

      assert has_element?(
               view,
               "p",
               "Give your course section a name, a number, and tell us how you meet."
             )

      assert has_element?(view, "h4", "Course details")

      assert has_element?(
               view,
               "p",
               "If you meet as a group, let us know what days of the week your class meets. Tell us your course’s start and end dates."
             )
    end
  end

  describe "wizard footer restyle" do
    setup [:instructor_conn]

    test "the Cancel button carries the course-creation-only border override (present on every step)",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "#course_creation_stepper")

      assert has_element?(
               view,
               ~s(button.torus-button.secondary[class*="Border-border-bold"]),
               "Cancel"
             )
    end

    test "the (enabled) Next Step button carries the course-creation-only fill override once a source is selected",
         %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "button[disabled]", "Next step")

      view
      |> element(".card-deck a:first-child")
      |> render_click(id: "publication:#{section.id}")

      assert has_element?(view, "h2", "Name your course")

      refute has_element?(view, "button[disabled]", "Next step")

      assert has_element?(
               view,
               ~s(button.torus-button.primary[class*="Fill-Buttons-fill-primary-bold"]),
               "Next step"
             )
    end
  end
end

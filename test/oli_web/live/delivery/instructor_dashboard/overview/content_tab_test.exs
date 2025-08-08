defmodule OliWeb.Delivery.InstructorDashboard.Overview.Content do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  defp instructor_course_content_path(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :course_content
    )
  end

  defp section_with_larger_hierarchy(%{instructor: instructor} = _conn) do
    %{section: section, mod1_pages: mod1_pages} = Oli.Seeder.base_project_with_larger_hierarchy()
    enroll_user_to_section(instructor, section, :context_instructor)

    %{section: section, mod1_pages: mod1_pages}
  end

  describe "Instructor dashboard overview - course tab" do
    setup [:instructor_conn, :section_with_larger_hierarchy]

    test "renders the course tab correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Page 1")

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "h4", "Page 2")

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "h4", "Unit 1")

      assert has_element?(
               view,
               "span",
               "Find all your course content, material, assignments and class activities here."
             )

      assert has_element?(view, "a", "Open as instructor")
    end
  end
end

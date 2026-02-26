defmodule OliWeb.Delivery.InstructorDashboard.Overview.Content do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections

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
    %{section: section, mod1_pages: mod1_pages, unit1_resource: unit1_resource} =
      Oli.Seeder.base_project_with_larger_hierarchy()

    enroll_user_to_section(instructor, section, :context_instructor)

    %{section: section, mod1_pages: mod1_pages, unit1_resource: unit1_resource}
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

    test "shows updated section title for a unit in course content", %{
      conn: conn,
      section: section,
      unit1_resource: unit1_resource
    } do
      unit_1_section_resource = Sections.get_section_resource(section.id, unit1_resource.id)
      updated_title = "Updated Unit 1 Title"

      assert {:ok, _updated_sr} =
               Sections.update_section_resource(unit_1_section_resource, %{title: updated_title})

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "h4", updated_title)
    end
  end
end

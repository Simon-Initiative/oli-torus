defmodule OliWeb.Delivery.InstructorDashboard.Overview.Content do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot

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
    %{section: section} = Oli.Seeder.base_project_with_larger_hierarchy()

    enroll_user_to_section(instructor, section, :context_instructor)

    %{section: section}
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

    test "shows updated section title for a page in course content", %{
      conn: conn,
      section: section
    } do
      updated_title = "Updated Page 1 Title"

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      view
      |> element("h4[phx-click='go_down']", "1.1 Module 1")
      |> render_click()

      page_1_resource_id =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{h4[phx-click="go_down"][phx-value-resource_type="page"]})
        |> List.first()
        |> Floki.attribute("phx-value-resource_id")
        |> List.first()
        |> String.to_integer()

      page_1_section_resource = Sections.get_section_resource(section.id, page_1_resource_id)

      assert {:ok, updated_sr} =
               Sections.update_section_resource(page_1_section_resource, %{title: updated_title})

      SectionResourceDepot.update_section_resource(updated_sr)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      view
      |> element("h4[phx-click='go_down']", "1.1 Module 1")
      |> render_click()

      assert has_element?(
               view,
               ~s{h4[phx-click="go_down"][phx-value-resource_type="page"][phx-value-resource_id="#{page_1_resource_id}"]},
               updated_title
             )
    end
  end
end

defmodule OliWeb.Delivery.InstructorDashboard.Overview.Content do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.ResourceType

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

  # A single suppressed top-level unit, titled unlike any numbered-label format (not
  # "Unit N"), so a bare-title-fallback assertion can't be confused with the numbered
  # form -- unlike the shared `Oli.Seeder.base_project_with_larger_hierarchy/0` fixture
  # above, whose "Unit 1" title happens to look identical to its own numbered label.
  defp section_with_suppressible_unit(%{instructor: instructor} = _conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Getting Started")

    unit_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_revision.resource_id],
        title: "Foundations"
      )

    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_revision.resource_id],
        title: "Root Container"
      )

    all_revisions = [page_revision, unit_revision, container_revision]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: container_revision.resource_id)

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    enroll_user_to_section(instructor, section, :context_instructor)

    %{section: section, unit_resource: unit_revision.resource}
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

  describe "Instructor dashboard overview - course tab, suppressed unit" do
    setup [:instructor_conn, :section_with_suppressible_unit]

    test "shows the bare title, with no numbering prefix, for a suppressed top-level unit",
         %{conn: conn, section: section, unit_resource: unit_resource} do
      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit_resource.id]})

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      # "Foundations" is the only top-level node, so it's already the current one -- no
      # navigation needed to reach it.
      assert has_element?(view, "#course_browser_node_title", "Foundations")
    end
  end
end

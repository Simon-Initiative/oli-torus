defmodule OliWeb.Sections.LtiExternalToolsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  defp live_view_lti_external_tools_route(section_slug) do
    ~p"/sections/#{section_slug}/lti_external_tools"
  end

  defp create_elixir_project(_context) do
    author = insert(:author)
    project = insert(:project)

    # Create two LTI activity registrations (tools)

    lti_tool1 = insert(:activity_registration, title: "Tool One")
    lti_tool2 = insert(:activity_registration, title: "Tool Two")

    platform1 =
      insert(:platform_instance, %{
        name: "Platform One",
        description: "First platform"
      })

    platform2 =
      insert(:platform_instance, %{
        name: "Platform Two",
        description: "Second platform"
      })

    _deployment1 =
      insert(:lti_external_tool_activity_deployment,
        activity_registration: lti_tool1,
        platform_instance: platform1
      )

    _deployment2 =
      insert(:lti_external_tool_activity_deployment,
        activity_registration: lti_tool2,
        platform_instance: platform2
      )

    # Create tool revisions
    tool1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: lti_tool1.id,
        title: "Tool One Activity Revision"
      })

    tool2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("activity"),
        activity_type_id: lti_tool2.id,
        title: "Tool Two Activity Revision"
      })

    # Create page revisions that reference the tool revisions
    page1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page One",
        activity_refs: [tool1_revision.resource_id, tool2_revision.resource_id]
      })

    page2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Page Two",
        activity_refs: [tool2_revision.resource_id]
      })

    # Create a container revision (root)
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        title: "Root Container",
        children: [page1_revision.resource_id, page2_revision.resource_id]
      })

    all_revisions = [
      tool1_revision,
      tool2_revision,
      page1_revision,
      page2_revision,
      container_revision
    ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, project: project, root_resource_id: container_revision.resource_id)

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # Create section
    section =
      insert(:section,
        base_project: project,
        analytics_version: :v2,
        type: :enrollable
      )

    {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_pages(section)
    {:ok, _} = Oli.Delivery.Sections.rebuild_contained_objectives(section)
    Oli.Delivery.Sections.SectionResourceMigration.migrate(section.id)

    %{
      section: section,
      tool1: lti_tool1,
      tool2: lti_tool2,
      page1: page1_revision,
      page2: page2_revision
    }
  end

  describe "instructor" do
    setup [:instructor_conn, :create_elixir_project]

    test "can access correctly", %{conn: conn, section: section, instructor: instructor} do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, _view, html} = live(conn, live_view_lti_external_tools_route(section.slug))
      assert html =~ "LTI 1.3 External Tools"
    end

    test "lists LTI tools and their pages", %{
      conn: conn,
      section: section,
      instructor: instructor,
      tool1: tool1,
      tool2: tool2
    } do
      {:ok, _} =
        Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_lti_external_tools_route(section.slug))

      # Tool One
      #  |_ Page One
      assert has_element?(view, "div[id='lti_external_tool_#{tool1.id}'] button", "Tool One")
      assert has_element?(view, "div[id='lti_external_tool_#{tool1.id}'] li", "Page One")
      refute has_element?(view, "div[id='lti_external_tool_#{tool1.id}'] li", "Page Two")

      # Tool Two
      #  |_ Page One
      #  |_ Page Two
      assert has_element?(view, "div[id='lti_external_tool_#{tool2.id}'] button", "Tool Two")
      assert has_element?(view, "div[id='lti_external_tool_#{tool2.id}'] li", "Page One")
      assert has_element?(view, "div[id='lti_external_tool_#{tool2.id}'] li", "Page Two")
    end

    test "shows warning icon and message when tool is removed", %{
      conn: conn,
      section: section,
      instructor: instructor,
      tool1: tool1
    } do
      {:ok, _} =
        Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      deployment =
        Oli.Repo.get_by!(Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment,
          activity_registration_id: tool1.id
        )

      Ecto.Changeset.change(deployment, status: :deleted) |> Oli.Repo.update!()

      {:ok, view, _html} = live(conn, live_view_lti_external_tools_route(section.slug))

      assert has_element?(view, "#lti_external_tool_#{tool1.id} svg")
      assert render(view) =~ "This tool is no longer registered in the system"
    end
  end

  describe "admin" do
    setup [:admin_conn, :create_elixir_project]

    test "can access correctly", %{conn: conn, section: section} do
      {:ok, _view, html} = live(conn, live_view_lti_external_tools_route(section.slug))

      assert html =~ "LTI 1.3 External Tools"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "cannot access and gets redirected", %{conn: conn, section: section, user: user} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: "/unauthorized", flash: %{}}}} =
        live(conn, live_view_lti_external_tools_route(section.slug))
    end
  end
end

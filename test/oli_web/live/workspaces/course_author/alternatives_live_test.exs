defmodule OliWeb.Workspaces.CourseAuthor.AlternativesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Resources.ResourceType

  defp live_view_alternatives_route(project_slug),
    do: ~p"/workspaces/course_author/#{project_slug}/alternatives"

  describe "alternatives view" do
    setup [:admin_conn, :create_project]

    test "shows only learner preference alternatives", %{conn: conn, project: project} do
      insert_alternatives_group(project, "Decision Point", "upgrade_decision_point")
      insert_alternatives_group(project, "Learner Preference", "user_section_preference")
      insert_alternatives_group(project, "Legacy Alternative", nil)

      {:ok, view, _html} = live(conn, live_view_alternatives_route(project.slug))

      refute has_element?(view, "button", "New A/B Decision Point")
      refute has_element?(view, ".alternatives-group", "Decision Point")
      assert has_element?(view, ".alternatives-group", "Learner Preference")
      assert has_element?(view, ".alternatives-group", "Legacy Alternative")
    end
  end

  defp create_project(_conn) do
    insert(:institution)
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    [project: project]
  end

  defp insert_alternatives_group(project, title, strategy) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: title,
        deleted: false,
        content:
          case strategy do
            nil -> %{"options" => []}
            strategy -> %{"strategy" => strategy, "options" => []}
          end
      })

    publication = Oli.Publishing.project_working_publication(project.slug)
    insert(:published_resource, publication: publication, resource: resource, revision: revision)
  end
end

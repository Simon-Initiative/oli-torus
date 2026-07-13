defmodule OliWeb.Workspaces.CourseAuthor.AlternativesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Ecto.Query
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  defp live_view_alternatives_route(project_slug),
    do: ~p"/workspaces/course_author/#{project_slug}/alternatives"

  describe "alternatives view" do
    setup [:admin_conn, :create_project]

    test "creates a native A/B Testing decision point", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_alternatives_route(project.slug))

      assert has_element?(view, "button", "New A/B Decision Point")

      view
      |> element("button", "New A/B Decision Point")
      |> render_click()

      view
      |> form("#create_modal form", %{"params" => %{"name" => "Decision Point 1"}})
      |> render_submit()

      assert has_element?(view, ".alternatives-group", "Decision Point 1")

      revision = latest_alternatives_revision(project.id, "Decision Point 1")
      assert revision.content["strategy"] == "upgrade_decision_point"
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

  defp latest_alternatives_revision(project_id, title) do
    Repo.one!(
      from revision in Revision,
        join: project_resource in ProjectResource,
        on: project_resource.resource_id == revision.resource_id,
        where:
          project_resource.project_id == ^project_id and
            revision.resource_type_id == ^ResourceType.id_for_alternatives() and
            revision.title == ^title,
        order_by: [desc: revision.id],
        limit: 1
    )
  end
end

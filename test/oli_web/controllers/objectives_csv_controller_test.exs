defmodule OliWeb.ObjectivesCsvControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Activities
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Seeder

  describe "download/2" do
    setup [:admin_conn]

    test "downloads the current project's objective map", %{conn: conn} do
      seed = Seeder.base_project_with_resource2()
      objective = create_objective(seed, "Objective, with comma")
      activity = create_activity(seed, objective.resource_id, "Practice Activity")

      seed.revision1
      |> Ecto.Changeset.change(activity_refs: [activity.resource_id])
      |> Repo.update!()

      conn =
        get(
          conn,
          ~p"/workspaces/course_author/#{seed.project.slug}/objectives.csv?sort_by=title&sort_order=asc"
        )

      assert response_content_type(conn, :csv) == "text/csv"

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"#{seed.project.slug}_learning_objectives.csv\""
             ]

      assert [
               [
                 "LO Label",
                 "LO Title",
                 "Sub-Objective",
                 "Activity Type",
                 "Activity Name",
                 "Page Name",
                 "Course Location"
               ],
               [
                 "LO 1",
                 "Objective, with comma",
                 "",
                 "Multiple Choice",
                 "Practice Activity",
                 "Page one",
                 ""
               ]
             ] = NimbleCSV.RFC4180.parse_string(conn.resp_body, skip_headers: false)
    end
  end

  test "requires an authenticated author", %{conn: conn} do
    seed = Seeder.base_project_with_resource2()

    conn = get(conn, ~p"/workspaces/course_author/#{seed.project.slug}/objectives.csv")

    assert redirected_to(conn) == ~p"/authors/log_in"
  end

  test "requires access to the requested project", %{conn: conn} do
    {:ok, context} = author_conn(%{conn: conn})
    seed = Seeder.base_project_with_resource2()

    conn = get(context[:conn], ~p"/workspaces/course_author/#{seed.project.slug}/objectives.csv")

    assert redirected_to(conn) == ~p"/workspaces/course_author"
  end

  defp create_objective(seed, title) do
    resource = insert(:resource)

    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: ResourceType.id_for_objective(),
        objectives: %{},
        children: [],
        title: title,
        deleted: false
      )

    attach_to_project(seed, resource, revision)
    revision
  end

  defp create_activity(seed, objective_id, title) do
    resource = insert(:resource)
    activity_type = Activities.get_registration_by_slug("oli_multiple_choice")

    revision =
      insert(:revision,
        resource: resource,
        resource_type_id: ResourceType.id_for_activity(),
        activity_type_id: activity_type.id,
        objectives: %{"part" => [objective_id]},
        scope: :embedded,
        title: title,
        deleted: false
      )

    attach_to_project(seed, resource, revision)
    revision
  end

  defp attach_to_project(seed, resource, revision) do
    insert(:project_resource, project_id: seed.project.id, resource_id: resource.id)

    insert(:published_resource,
      publication: seed.publication,
      resource: resource,
      revision: revision,
      author: seed.author
    )
  end
end

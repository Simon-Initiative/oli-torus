defmodule OliWeb.Workspaces.CourseAuthor.ActivityBankLiveTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest
  alias Oli.Resources.ResourceType

  defp live_view_route(project_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/activity_bank?#{params}"

  describe "user cannot access when is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing the activity bank view", %{
      conn: conn,
      project: project
    } do
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => _error_msg}}}} =
        live(conn, live_view_route(project.slug))

      assert redirect_path == "/authors/log_in"
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn, :create_project]

    test "redirects to projects view when accessing the activity bank view", %{
      conn: conn,
      project: project
    } do
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You don't have access to that project"

      {:ok, view, _html} = live(conn, redirect_path)

      assert view
             |> element("#button-new-project")
             |> render() =~ "New Project"
    end
  end

  describe "activity bank" do
    setup [:admin_conn, :create_project]

    test "includes reference to React component(s)", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "#eventIntercept [role='status']")

      render_hook(view, "survey_scripts_loaded", %{"success" => "success"})

      refute has_element?(view, "#eventIntercept [role='status']")

      assert has_element?(view, ~s(div[data-live-react-class='Components.ActivityBank']))
    end

    test "renders error message when failed to load scripts", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "#eventIntercept [role='status']")

      render_hook(view, "survey_scripts_loaded", %{"error" => "error_from_promises"})

      assert has_element?(view, "div[role='alert']")
    end

    test "editorMap does not include LTI activities", %{
      conn: conn,
      project: project,
      lti_activity1: lti_activity1,
      lti_activity2: lti_activity2
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      render_hook(view, "survey_scripts_loaded", %{"success" => "success"})

      [activity_bank_html] =
        render(view) |> Floki.parse_document!() |> Floki.find("#activity-bank")

      props_json = Floki.attribute(activity_bank_html, "data-live-react-props") |> List.first()
      {:ok, props} = Jason.decode(props_json)
      editor_map = props["editorMap"]

      # Ensure that they are NOT present in the editorMap (React props)
      editor_map_slugs = Map.keys(editor_map)

      assert Enum.all?([lti_activity1.slug, lti_activity2.slug], fn slug ->
               slug not in editor_map_slugs
             end)

      assert Enum.all?(editor_map, fn {_slug, entry} -> entry["isLtiActivity"] == false end)
    end
  end

  ##### HELPER FUNCTIONS #####

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    lti_activity1 =
      insert(:activity_registration, %{
        slug: "lti_activity_1",
        title: "LTI Activity 1"
      })

    lti_activity2 =
      insert(:activity_registration, %{
        slug: "lti_activity_2",
        title: "LTI Activity 2"
      })

    insert(:lti_external_tool_activity_deployment, %{
      activity_registration: lti_activity1
    })

    insert(:lti_external_tool_activity_deployment, %{
      activity_registration: lti_activity2
    })

    # root container
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.id_for_container(),
        content: %{},
        slug: "root_container",
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})
    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    [
      project: project,
      publication: publication,
      lti_activity1: lti_activity1,
      lti_activity2: lti_activity2
    ]
  end
end

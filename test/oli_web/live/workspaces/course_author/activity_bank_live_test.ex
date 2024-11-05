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
      {:error, {:redirect, %{to: redirect_path, flash: %{"error" => error_msg}}}} =
        live(conn, live_view_route(project.slug))

      assert redirect_path == "/workspaces/course_author"
      assert error_msg == "You must be logged in to access that project"

      {:ok, _view, html} = live(conn, redirect_path)

      assert html =~
               "<span class=\"text-white font-normal font-[&#39;Open Sans&#39;] leading-10\">\n            Welcome to\n          </span><span class=\"text-white font-bold font-[&#39;Open Sans&#39;] leading-10\">\n            OLI Torus\n          </span>"
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
      assert has_element?(view, ~s(div[data-live-react-class='Components.ModalDisplay']))
    end
  end

  ##### HELPER FUNCTIONS #####

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])
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

    [project: project, publication: publication]
  end
end

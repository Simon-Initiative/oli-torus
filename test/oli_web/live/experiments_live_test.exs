defmodule OliWeb.ExperimentsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  defp live_view_experiments_route(project_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Experiments.ExperimentsView,
      project_slug
    )
  end

  defp create_project(_conn) do
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the experiments view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fexperiments"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fexperiments"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an instructor" do
    setup [:instructor_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fexperiments"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "experiments view" do
    setup [:admin_conn, :create_project]

    test "loads experiments view correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      assert view
             |> element("h3")
             |> render() =~
               "A/B Testing with UpGrade"

      assert view
             |> element("p")
             |> render() =~
               "To support A/B testing, Torus integrates with the A/B testing platform"

      assert has_element?(
               view,
               "label",
               "Enable A/B testing with UpGrade"
             )
    end
  end
end

defmodule OliWeb.ExperimentsLiveTest do
  use ExUnit.Case, async: true
  alias Oli.Resources.Revision
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  defp live_view_experiments_route(project_slug) do
    ~p"/authoring/project/#{project_slug}/experiments"
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

    test "check, then uncheck, when no previous experiment exists", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      refute has_element?(view, ".alternatives-group")

      # Checking checkbox
      view |> element("input[phx-click=\"enable_upgrade\"]") |> render_click()

      assert has_element?(view, ".alternatives-group", "Decision Point")
      assert has_element?(view, ".list-group", "Option 1")
      assert has_element?(view, ".list-group", "Option 2")
      refute has_element?(view, ".list-group", "Option 3")

      [resource_id] =
        view
        |> element("button[phx-click=\"show_edit_group_modal\"]")
        |> render()
        |> Floki.attribute("phx-value-resource-id")

      [option_1, option_2] =
        Oli.Repo.get_by!(Revision, resource_id: resource_id).content["options"]

      assert view
             |> has_element?(
               "button[phx-click=\"show_edit_group_modal\"][phx-value-resource-id=\"#{resource_id}\"] > .fa-pencil"
             )

      assert view
             |> has_element?(
               "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-pencil"
             )

      assert view
             |> has_element?(
               "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-pencil"
             )

      assert view
             |> has_element?(
               "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-trash"
             )

      assert view
             |> has_element?(
               "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-trash"
             )

      assert view
             |> element(
               "button[phx-click=\"show_create_option_modal\"][phx-value-resource_id=\"#{resource_id}\"]"
             )
             |> render() =~ "New Option"

      # Unchecking checkbox
      view |> element("input[phx-click=\"enable_upgrade\"]") |> render_click()

      refute view
             |> has_element?(
               "button[phx-click=\"show_edit_group_modal\"][phx-value-resource-id=\"#{resource_id}\"] > .fa-pencil"
             )

      refute view
             |> has_element?(
               "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-pencil"
             )

      refute view
             |> has_element?(
               "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-pencil"
             )

      refute view
             |> has_element?(
               "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-trash"
             )

      refute view
             |> has_element?(
               "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-trash"
             )

      refute view
             |> has_element?(
               "button[phx-click=\"show_create_option_modal\"][phx-value-resource_id=\"#{resource_id}\"]"
             )

      assert has_element?(view, ".alternatives-group", "Decision Point")
      assert has_element?(view, ".list-group", "Option 1")
      assert has_element?(view, ".list-group", "Option 2")
    end
  end
end

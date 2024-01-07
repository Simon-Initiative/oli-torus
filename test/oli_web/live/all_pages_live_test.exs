defmodule OliWeb.AllPagesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  defp live_view_all_pages_route(project_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Resources.PagesView,
      project_slug
    )
  end

  defp insert_pages(project, publication, count) do
    Enum.map(3..count, fn index ->
      nested_page_resource = insert(:resource)

      nested_page_revision =
        insert(:revision, %{
          objectives: %{"attached" => []},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          children: [],
          content: %{"model" => []},
          deleted: false,
          title: "Nested page #{index}",
          resource: nested_page_resource
        })

      insert(:project_resource, %{project_id: project.id, resource_id: nested_page_resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: nested_page_resource,
        revision: nested_page_revision
      })
    end)
  end

  defp create_project_without_pages(_conn) do
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
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
    test "redirects to new session when accessing the all pages view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fpages"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_all_pages_route(project.slug))
    end
  end

  describe "all pages view" do
    setup [:admin_conn, :base_project_with_curriculum]

    test "loads all pages view correctly", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision
    } do
      {:ok, view, _html} = live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("h3")
             |> render() =~
               "Browse All Pages"

      assert has_element?(
               view,
               "a[href=\"/authoring/project/#{project.slug}/curriculum\"]",
               "Curriculum"
             )

      assert has_element?(view, "button", "Create")

      assert has_element?(
               view,
               "input[id=\"text-search-input\"]"
             )

      assert has_element?(
               view,
               "select[name=\"graded\"][id=\"select_graded\"]"
             )

      assert has_element?(
               view,
               "select[name=\"type\"][id=\"select_type\"]"
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )
    end

    test "loads correctly when there are no pages in the project", %{
      conn: conn
    } do
      [project: project] = create_project_without_pages(conn)

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(view, "p", "There are no pages in this project")
    end

    test "applies filtering", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(2) td:nth-child(1)",
               nested_page_revision_2.title
             )

      view
      |> element("form[phx-change=\"change_graded\"")
      |> render_change(%{"graded" => true})

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision_2.title
             )

      refute has_element?(
               view,
               nested_page_revision.title
             )
    end

    test "applies searching", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(2) td:nth-child(1)",
               nested_page_revision_2.title
             )

      view
      |> element("#text-search-input")
      |> render_hook("text_search_change", %{value: nested_page_revision.title})

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      refute has_element?(
               view,
               nested_page_revision_2.title
             )
    end

    test "applies sorting", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~
               nested_page_revision.title

      # Sort by title desc
      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~
               nested_page_revision_2.title
    end

    test "applies paging", %{
      conn: conn,
      project: project,
      publication: publication,
      nested_page_revision: nested_page_revision
    } do
      [_first_page | tail] =
        insert_pages(project, publication, 26) |> Enum.sort_by(& &1.revision.title)

      last_page = List.last(tail)

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               nested_page_revision.title

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_page.revision.title

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               nested_page_revision.title

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_page.revision.title
    end

    test "can navigate to curriculum view", %{conn: conn, project: project} do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      view
      |> element("a[role='go_to_curriculum']", "Curriculum")
      |> render_click()

      assert_redirect(
        view,
        ~p"/authoring/project/#{project.slug}/curriculum"
      )
    end
  end
end

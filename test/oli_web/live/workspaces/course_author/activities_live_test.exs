defmodule OliWeb.Workspaces.CourseAuthor.ActivitiesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Workspaces.CourseAuthor.ActivitiesLive

  defp live_view_all_activities_route(project_slug) do
    Routes.live_path(OliWeb.Endpoint, ActivitiesLive, project_slug)
  end

  describe "user cannot access when is not logged in" do
    test "redirects to overview when accessing the all activities view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/workspaces/course_author"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_all_activities_route(project.slug))
    end
  end

  describe "all activities view" do
    setup [:admin_conn, :create_full_project_with_objectives]

    test "loads all activities view correctly", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      {:ok, view, _html} = live(conn, live_view_all_activities_route(project.slug))

      assert view
             |> element("#header_id")
             |> render() =~
               "Browse All Activities"

      assert has_element?(
               view,
               "input[id=\"text-search-input\"]"
             )

      assert has_element?(
               view,
               "table tbody tr:last-child td:nth-child(2)",
               revisions.act_revision_w.title
             )
    end

    test "loads correctly when there are no activities in the project", %{
      conn: conn
    } do
      %{project: project} = base_project_with_curriculum(nil)

      {:ok, view, _html} =
        live(conn, live_view_all_activities_route(project.slug))

      assert has_element?(view, "div", "None exist")
    end

    test "applies sorting", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_activities_route(project.slug))

      ## Sort by title asc
      view
      |> element("th[phx-click=\"paged_table_sort\"][phx-value-sort_by=\"title\"]")
      |> render_click()

      assert view
             |> element("tr:first-child td:nth-child(2) > div")
             |> render() =~
               revisions.act_revision_w.title

      assert view
             |> element("tr:last-child(2) td:nth-child(2) > div")
             |> render() =~
               revisions.act_revision_z.title

      ## Sort by title desc
      view
      |> element("th[phx-click=\"paged_table_sort\"][phx-value-sort_by=\"title\"]")
      |> render_click()

      assert view
             |> element("tr:first-child td:nth-child(2) > div")
             |> render() =~
               revisions.act_revision_z.title

      assert view
             |> element("tr:last-child(2) td:nth-child(2) > div")
             |> render() =~
               revisions.act_revision_w.title
    end

    test "go to the page edit view works correctly", %{
      conn: conn,
      project: project,
      revisions: revisions,
      admin: admin
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_activities_route(project.slug))

      view
      |> element(
        "a[href=\"/workspaces/course_author/#{project.slug}/curriculum/#{revisions.page_revision_1.slug}/edit\"]",
        revisions.page_revision_1.title
      )
      |> render_click()

      conn = recycle_author_session(conn, admin)

      ## Go to the page edit view
      {:ok, view, _html} =
        live(
          conn,
          "/workspaces/course_author/#{project.slug}/curriculum/#{revisions.page_revision_1.slug}/edit"
        )

      assert view
             |> element("li[aria-current=\"page\"]")
             |> render() =~ revisions.page_revision_1.title
    end
  end
end

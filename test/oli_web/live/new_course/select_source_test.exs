defmodule OliWeb.NewCourse.SelectSourceTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publications.Publication

  import Phoenix.LiveViewTest
  import Oli.Factory

  @live_view_admin_route Routes.select_source_path(OliWeb.Endpoint, :admin)
  @live_view_independent_learner_route Routes.select_source_path(
                                         OliWeb.Endpoint,
                                         :independent_learner
                                       )
  @live_view_lms_instructor_route Routes.select_source_path(OliWeb.Endpoint, :lms_instructor)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the admin view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, @live_view_admin_route)
    end

    test "redirects to new session when accessing the independent instructor view", %{conn: conn} do
      {:error, {:redirect, %{to: "/users/log_in"}}} =
        live(conn, @live_view_independent_learner_route)
    end

    test "redirects to new session when accessing the lms instructor view", %{conn: conn} do
      {:error, {:redirect, %{to: "/users/log_in"}}} =
        live(conn, @live_view_lms_instructor_route)
    end
  end

  describe "Admin - Step 1" do
    setup [:admin_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "button[disabled]", "Next step")
    end

    test "loads correctly when there are sections in table view", %{conn: conn} do
      section = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert has_element?(view, "h2", "Select source")
      assert has_element?(view, "button[phx-click=\"source_selection\"]")
      refute has_element?(view, "img[alt=\"course image\"]")
      refute has_element?(view, "form#update_view_type")

      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "#{section.title}"
    end

    test "applies searching (case insensitive)", %{conn: conn} do
      s1 = insert(:section, %{title: "testing", open_and_free: true})
      s2 = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("input[placeholder=\"Search...\"]")
      |> render_blur(%{value: "Testing"})

      view
      |> element("button", "Search")
      |> render_click()

      assert has_element?(view, "div", s1.title)
      refute has_element?(view, "div", s2.title)

      view
      |> element("button#reset_search")
      |> render_click()

      assert has_element?(view, "div", s1.title)
      assert has_element?(view, "div", s2.title)
    end

    test "applies sorting", %{conn: conn} do
      insert(:section, %{title: "Testing A", open_and_free: true})
      insert(:section, %{title: "Testing B", open_and_free: true})

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("th[phx-value-sort_by=\"title\"]")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "Testing A"

      view
      |> element("th[phx-value-sort_by=\"title\"")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child + td")
             |> render() =~ "Testing B"
    end

    test "applies paging", %{conn: conn} do
      [first_s | tail] =
        insert_list(21, :section, open_and_free: true) |> Enum.sort_by(& &1.title)

      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      view
      |> element("th[phx-value-sort_by=\"title\"")
      |> render_click(%{sort_by: "title"})

      assert has_element?(view, "div", first_s.title)
      refute has_element?(view, "div", last_s.title)

      view
      |> element(".page-item button", "2")
      |> render_click()

      refute has_element?(view, "div", first_s.title)
      assert has_element?(view, "div", last_s.title)
    end

    test "successfully goes to the next step", %{conn: conn} do
      section = insert(:section, open_and_free: true, type: :blueprint)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert has_element?(view, "button[disabled]", "Next step")

      view
      |> element("button[phx-click=\"source_selection\"]")
      |> render_click(%{id: "product:#{section.id}"})

      refute has_element?(view, "h2", "Select source")
      assert has_element?(view, "h2", "Name your course")
    end

    test "renders datetimes using the local timezone", context do
      {:ok, conn: conn, ctx: session_context} = set_timezone(context)
      section = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, @live_view_admin_route)

      assert view
             |> element("tr:last-child > td:last-child")
             |> render() =~
               OliWeb.Common.Utils.render_date(section, :inserted_at, session_context)
    end
  end

  describe "LMS - Step 1" do
    setup [:lms_instructor_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "button[disabled]", "Next step")
    end

    test "loads correctly when there are sections in cards view", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "h2", "Select source")
      refute has_element?(view, "button[phx-click=\"source_selection\"]")
      assert has_element?(view, "img[alt=\"course image\"]")
      assert has_element?(view, "form#update_view_type")
      refute has_element?(view, "a[href=\"#{details_view(section)}\"]")
      assert has_element?(view, "h5", "#{section.title}")
    end

    test "applies searching (case insensitive)", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      s1 = insert(:section, %{base_project: project, title: "testing"})
      s2 = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("input[placeholder=\"Search...\"]")
      |> render_blur(%{value: "Testing"})

      view
      |> element("button", "Search")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      refute has_element?(view, "h5", "#{s2.title}")

      view
      |> element("button#reset_search")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      assert has_element?(view, "h5", "#{s2.title}")
    end

    test "applies view change", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#update_view_type")
      |> render_change(%{"view" => %{"type" => "list"}})

      assert has_element?(view, "button[phx-click=\"source_selection\"]")
      refute has_element?(view, "img[alt=\"course image\"]")
    end

    test "applies sorting", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, %{base_project: project, title: "Testing A"})
      insert(:section, %{base_project: project, title: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing B"

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing A"
    end

    test "applies paging", %{conn: conn} do
      %Publication{id: publication_id, project: project} = insert(:publication)

      [_first_s | tail] =
        insert_list(21, :section, base_project: project) |> Enum.sort_by(& &1.title)

      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      refute has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")

      view
      |> element(".page-item button", "2")
      |> render_click()

      refute has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      assert has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")
    end

    test "successfully goes to the next step", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "button[disabled]", "Next step")

      view
      |> element(".card-deck a:first-child")
      |> render_click(id: "publication:#{section.id}")

      refute has_element?(view, "h2", "Select source")
      assert has_element?(view, "h2", "Name your course")
    end

    test "renders datetimes using the local timezone", context do
      {:ok, conn: conn, ctx: session_context} = set_timezone(context)

      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert view
             |> element(".card-deck:last-child")
             |> render() =~
               OliWeb.Common.Utils.render_date(section, :inserted_at, session_context)
    end
  end

  describe "Independet instructor - Step 1" do
    setup [:instructor_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "button[disabled]", "Next step")
    end

    test "loads correctly when there are sections in cards view", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "h2", "Select source")
      refute has_element?(view, "button[phx-click=\"source_selection\"]")
      assert has_element?(view, "img[alt=\"course image\"]")
      assert has_element?(view, "form#update_view_type")
      refute has_element?(view, "a[href=\"#{details_view(section)}\"]")
      assert has_element?(view, "h5", "#{section.title}")
    end

    test "applies searching", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      s1 = insert(:section, %{base_project: project, title: "Testing"})
      s2 = insert(:section, %{base_project: project})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("input[placeholder=\"Search...\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button", "Search")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      refute has_element?(view, "h5", "#{s2.title}")

      view
      |> element("button#reset_search")
      |> render_click()

      assert has_element?(view, "h5", "#{s1.title}")
      assert has_element?(view, "h5", "#{s2.title}")
    end

    test "applies view change", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#update_view_type")
      |> render_change(%{"view" => %{"type" => "list"}})

      assert has_element?(view, "button[phx-click=\"source_selection\"]")
      refute has_element?(view, "img[alt=\"course image\"]")
    end

    test "applies sorting", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      insert(:section, %{base_project: project, title: "Testing A"})
      insert(:section, %{base_project: project, title: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing B"

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card-deck:last-child")
             |> render() =~ "Testing A"
    end

    test "applies paging", %{conn: conn} do
      %Publication{id: publication_id, project: project} = insert(:publication)

      [_first_s | tail] =
        insert_list(21, :section, base_project: project) |> Enum.sort_by(& &1.title)

      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      view
      |> element("form#sort")
      |> render_change(%{sort_by: "title"})

      assert has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      refute has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")

      view
      |> element(".page-item button", "2")
      |> render_click()

      refute has_element?(view, "a[phx-value-id=\"publication:#{publication_id}\"]")
      assert has_element?(view, "a[phx-value-id=\"product:#{last_s.id}\"]")
    end

    test "successfully goes to the next step", %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert has_element?(view, "button[disabled]", "Next step")

      view
      |> element(".card-deck a:first-child")
      |> render_click(id: "publication:#{section.id}")

      refute has_element?(view, "button[disabled]", "Next step")
      refute has_element?(view, "h2", "Select source")
      assert has_element?(view, "h2", "Name your course")
    end

    test "renders datetimes using the local timezone", context do
      {:ok, conn: conn, ctx: session_context} = set_timezone(context)

      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      assert view
             |> element(".card-deck:last-child")
             |> render() =~
               OliWeb.Common.Utils.render_date(section, :inserted_at, session_context)
    end
  end

  defp details_view(%Section{type: :blueprint} = section),
    do: Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section.slug)

  defp details_view(section),
    do: ~p"/workspaces/course_author/#{section.project.slug}/overview"
end

defmodule OliWeb.Sections.AdminIndexLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  import Phoenix.LiveViewTest
  import Oli.Factory

  @live_view_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, @live_view_index_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the index view", %{conn: conn} do
      conn = get(conn, @live_view_index_route)

      assert redirected_to(conn) == "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "loads correctly when there are no sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "#header_id", "Browse Course Sections")
      assert has_element?(view, "p", "None exist")
    end

    test "loads correctly when there are sections", %{conn: conn} do
      project = insert(:project, authors: [])
      institution = insert(:institution)

      section =
        insert(:section,
          type: :enrollable,
          base_project: project,
          institution: institution
        )

      u1 = insert(:user)
      u2 = insert(:user)
      Sections.enroll(u1.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(u2.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "td", section.title)
      assert has_element?(view, "td", project.title)
      assert has_element?(view, "td", institution.name)
      assert has_element?(view, "td", "#{u1.name}, #{u2.name}")
    end

    test "applies filtering", %{conn: conn} do
      s1 =
        insert(:section,
          type: :enrollable,
          open_and_free: true,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      s2 = insert(:section, type: :enrollable, status: :deleted)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "td", s1.title)
      assert has_element?(view, "td", s2.title)

      # by active date
      view
      |> element("input[phx-click=\"active_today\"]")
      |> render_click()

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)

      # reset filter active date
      view
      |> element("input[phx-click=\"active_today\"]")
      |> render_click()

      # by type
      view
      |> element("form[phx-change=\"change_type\"]")
      |> render_change(%{"type" => "open"})

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)

      view
      |> element("form[phx-change=\"change_type\"]")
      |> render_change(%{"type" => "lms"})

      refute has_element?(view, "td", s1.title)
      assert has_element?(view, "td", s2.title)

      # reset filter type
      view
      |> element("form[phx-change=\"change_type\"]")
      |> render_change(%{"type" => ""})

      # by status
      view
      |> element("form[phx-change=\"change_status\"]")
      |> render_change(%{"status" => "active"})

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)

      view
      |> element("form[phx-change=\"change_status\"]")
      |> render_change(%{"status" => "deleted"})

      refute has_element?(view, "td", s1.title)
      assert has_element?(view, "td", s2.title)

      view
      |> element("form[phx-change=\"change_status\"]")
      |> render_change(%{"status" => "archived"})

      refute has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)
      assert has_element?(view, "p", "None exist")
    end

    test "applies searching", %{conn: conn} do
      project = insert(:project, title: "Project", authors: [])
      other_project = insert(:project, title: "OtherProj", authors: [])
      institution = insert(:institution, name: "OtherInsti")
      blueprint = insert(:section, title: "TestSection")

      s1 =
        insert(:section,
          type: :enrollable,
          base_project: other_project,
          title: "Testing",
          blueprint: blueprint
        )

      s2 = insert(:section, type: :enrollable, base_project: project, institution: institution)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      # by title
      render_hook(view, "text_search_change", %{value: "testing"})

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)

      # by institution
      render_hook(view, "text_search_change", %{value: "otherins"})

      refute has_element?(view, "td", s1.title)
      assert has_element?(view, "td", s2.title)

      # by product
      render_hook(view, "text_search_change", %{value: "testsection"})

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)

      # by project
      render_hook(view, "text_search_change", %{value: "project"})

      refute has_element?(view, "td", s1.title)
      assert has_element?(view, "td", s2.title)

      # by instructor
      user = insert(:user, name: "Instructor")
      Sections.enroll(user.id, s1.id, [ContextRoles.get_role(:context_instructor)])

      render_hook(view, "text_search_change", %{value: "instructor"})

      assert has_element?(view, "td", s1.title)
      refute has_element?(view, "td", s2.title)
    end

    test "applies sorting", %{conn: conn} do
      project = insert(:project, title: "Project", authors: [])

      s1 =
        insert(:section, type: :enrollable, amount: Money.new(:USD, 100_000), title: "Section A")

      s2 = insert(:section, type: :enrollable, base_project: project, title: "Section B")

      {:ok, view, _html} = live(conn, @live_view_index_route)

      # by title
      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s1.title

      view
      |> element("th[phx-click=\"paged_table_sort\"]", "Title")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s2.title

      # by cost
      view
      |> element("th[phx-click=\"paged_table_sort\"]", "Cost")
      |> render_click(%{sort_by: "requires_payment"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s2.title

      view
      |> element("th[phx-click=\"paged_table_sort\"]", "Cost")
      |> render_click(%{sort_by: "requires_payment"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s1.title

      # by instructor
      user = insert(:user, name: "Instructor")
      Sections.enroll(user.id, s1.id, [ContextRoles.get_role(:context_instructor)])

      view
      |> element("th[phx-click=\"paged_table_sort\"]", "Instructor")
      |> render_click(%{sort_by: "instructor"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s2.title

      view
      |> element("th[phx-click=\"paged_table_sort\"]", "Instructor")
      |> render_click(%{sort_by: "instructor"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ s1.title
    end

    test "applies paging", %{conn: conn} do
      [first_s | tail] = insert_list(26, :section, type: :enrollable) |> Enum.sort_by(& &1.title)
      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "td", first_s.title)
      refute has_element?(view, "td", last_s.title)

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "td", first_s.title)
      assert has_element?(view, "td", last_s.title)
    end

    test "section title is a link to the manage tab of the instructor dashboard", %{conn: conn} do
      project = insert(:project, authors: [])
      institution = insert(:institution)

      section =
        insert(:section,
          type: :enrollable,
          base_project: project,
          institution: institution
        )

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(
               view,
               "a[href=\"#{~p"/sections/#{section.slug}/manage"}\"]",
               section.title
             )
    end

    test "enrolled column only shows student enrollments", %{conn: conn} do
      project = insert(:project, authors: [])

      section =
        insert(:section,
          type: :enrollable,
          base_project: project
        )

      students =
        insert_list(5, :user)

      instructor = insert(:user)

      number_of_student_enrollments =
        enroll_students_to_section(students, section)

      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element("table > tbody > tr:first-child > td:nth-child(3) > div")
             |> render() =~ number_of_student_enrollments
    end
  end

  defp enroll_students_to_section(students_list, section) do
    students_list
    |> Enum.map(fn student -> enroll_user_to_section(student, section, :context_learner) end)
    |> length()
    |> Integer.to_string()
  end
end

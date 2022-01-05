defmodule OliWeb.Sections.OverviewLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Lti_1p3.Tool.ContextRoles

  defp live_view_overview_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_overview_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/session/new?request_path=%2Fsections%2F#{section.slug}"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:user_conn]

    test "loads correctly", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert view
             |> render() =~
               "Overview"
    end
  end

  describe "overview live view" do
    setup [:admin_conn, :create_section]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_overview_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert view
             |> render() =~
               "Overview"

      assert view
             |> render() =~
               "Overview of this course section"

      assert has_element?(view, "input[value=\"#{section.slug}\"]")
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"LTI\"]")
    end

    test "loads section instructors correctly", %{conn: conn, section: section} do
      user_enrolled = insert(:user)
      user_not_enrolled = insert(:user, %{given_name: "Other"})

      Sections.enroll(user_enrolled.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert view
             |> render() =~
               "Instructors"

      assert view
             |> render() =~
               "Manage the users with instructor level access"

      assert view
             |> render() =~
               user_enrolled.given_name

      refute view
             |> render() =~
               user_not_enrolled.given_name
    end

    test "loads section links correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert view
             |> render() =~
               "Curriculum"

      assert view
             |> render() =~
               "Manage the content delivered to students"

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :updates, section.slug)}\"]"
             )

      assert view
             |> render() =~
               "Manage"

      assert view
             |> render() =~
               "Manage all aspects of course delivery"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsView, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug)}\"]"
             )

      assert view
             |> render() =~
               "Grading"

      assert view
             |> render() =~
               "View and manage student grades and progress"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, section.slug)}\"]"
             )
    end

    test "unlink section from lms", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert view
             |> render() =~
               "LMS Admin"

      assert view
             |> render() =~
               "Administrator LMS Connection"

      view
      |> element("button[phx-click=\"unlink\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :index))
      assert %Section{status: :deleted} = Sections.get_section!(section.id)
    end
  end
end

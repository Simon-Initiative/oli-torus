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

      {:ok, _view, html} = live(conn, live_view_overview_route(section.slug))

      refute html =~ "<nav aria-label=\"breadcrumb"
      assert html =~ "Overview"
    end
  end

  describe "admin is prioritized over instructor when both logged in" do
    setup [:admin_conn, :user_conn]

    test "loads correctly", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} = live(conn, live_view_overview_route(section.slug))

      assert html =~ "<nav aria-label=\"breadcrumb"
      assert html =~ "Overview"
    end
  end

  describe "overview live view" do
    setup [:admin_conn, :create_section]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_overview_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn} do
      section = insert(:section, open_and_free: true)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Overview"
      assert render(view) =~ "Overview of this course section"
      assert has_element?(view, "input[value=\"#{section.slug}\"]")
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"Direct Delivery\"]")
    end

    test "loads section instructors correctly", %{conn: conn, section: section} do
      user_enrolled = insert(:user)
      user_not_enrolled = insert(:user, %{given_name: "Other"})

      Sections.enroll(user_enrolled.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Instructors"
      assert render(view) =~ "Manage the users with instructor level access"
      assert render(view) =~ user_enrolled.given_name
      refute render(view) =~ user_not_enrolled.given_name
    end

    test "loads section links correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Curriculum"
      assert render(view) =~ "Manage the content delivered to students"

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
               "a[href=\"#{Routes.section_updates_path(OliWeb.Endpoint, OliWeb.Delivery.ManageUpdates, section.slug)}\"]"
             )

      assert render(view) =~ "Manage"
      assert render(view) =~ "Manage all aspects of course delivery"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsView, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug)}\"]"
             )

      assert render(view) =~ "Grading"
      assert render(view) =~ "View and manage student grades and progress"

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

      assert render(view) =~ "LMS Admin"
      assert render(view) =~ "Administrator LMS Connection"

      view
      |> element("button[phx-click=\"unlink\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :index))
      assert %Section{status: :deleted} = Sections.get_section!(section.id)
    end

    test "deletes a section when it has no students associated data", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~
               "This action cannot be undone. Are you sure you want to delete this section?"

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index))
      refute Sections.get_section_by_slug(section.slug)
    end

    test "archives a section when it has students associated data", %{conn: conn} do
      section = insert(:snapshot).section

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~ """
               This section has student data and will be archived rather than deleted.
               Are you sure you want to archive it? You will no longer have access to the data. Archiving this section will make it so students can no longer access it.
             """

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index))
      assert %Section{status: :archived} = Sections.get_section!(section.id)
    end

    test "displays a flash message when there is student activity after the modal shows up", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~
               "This action cannot be undone. Are you sure you want to delete this section?"

      # Add student activity to the section
      insert(:snapshot, section: section)

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      assert render(view) =~
               "Section had student activity recently. It can now only be archived, please try again."

      assert %Section{status: :active} = Sections.get_section!(section.id)
    end
  end
end

defmodule OliWeb.ProgressLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.{ContextRoles, PlatformRoles}
  alias Oli.Accounts
  alias Oli.Delivery.Sections

  defp live_view_student_resource_route(section_slug, user_id, resource_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Progress.StudentResourceView,
      section_slug,
      user_id,
      resource_id
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:create_resource]

    test "redirects to new session when accessing the student resource view", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{user.id}%2F#{resource.id}&section=#{section.slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_resource]

    test "redirects to section enroll page when accessing the student resource view", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      conn = get(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{user.id}%2F#{resource.id}&amp;section=#{section.slug}"

      assert conn
             |> get(live_view_student_resource_route(section.slug, user.id, resource.id))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "student resource" do
    setup [:admin_conn, :create_resource]

    test "loads student resource progress data correctly", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      {:ok, view, _html} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      html = render(view)
      assert html =~ "Details"
      assert html =~ "Attempt History"
    end
  end

  describe "admin breadcrumbs" do
    setup [:admin_conn, :create_resource]

    test "manual grading view", %{
      conn: conn,
      section: section
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, section.slug))

      {:ok, _view, html} = live(conn)

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "Manual Scoring"
    end

    test "student view", %{
      conn: conn,
      section: section,
      user: user
    } do
      {:ok, _view, html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, user.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "Student Progress"
    end

    test "student resource view", %{
      conn: conn,
      section: section,
      user: user,
      resource: resource
    } do
      {:ok, _view, html} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, user.id)}\""
      assert html =~ "View Resource Progress"
    end
  end

  describe "instructor breadcrumbs" do
    setup [:create_resource, :setup_instructor_session]

    test "manual grading view", %{
      conn: conn,
      section: section
    } do
      conn =
        get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, section.slug))

      {:ok, _view, html} = live(conn)

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)}\""
      assert html =~ "Manual Scoring"
    end

    test "student view", %{
      conn: conn,
      section: section,
      user: user
    } do
      {:ok, _view, html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, user.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)}\""
      assert html =~ "Student Progress"
    end

    test "student resource view", %{
      conn: conn,
      section: section,
      user: user,
      resource: resource
    } do
      {:ok, _view, html} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)}\""
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, user.id)}\""
      assert html =~ "View Resource Progress"
    end
  end

  def create_resource(_context) do
    user = insert(:user)
    project = insert(:project, authors: [user.author])
    section = insert(:section, type: :enrollable)

    section_project_publication =
      insert(:section_project_publication, %{section: section, project: project})

    revision = insert(:revision, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"))

    section_resource = insert(:section_resource, %{
      section: section,
      project: project,
      resource_id: revision.resource.id
    })

    Sections.update_section(section, %{root_section_resource_id: section_resource.id})

    insert(:published_resource, %{
      resource: revision.resource,
      revision: revision,
      publication: section_project_publication.publication,
      author: user.author
    })

    {:ok, section: section, resource: revision.resource, user: user}
  end

  defp setup_instructor_session(%{conn: conn, user: user, section: section}) do
    {:ok, user} =
      Accounts.update_user(user, %{can_create_sections: true, independent_learner: true})
    {:ok, instructor} =
      Accounts.update_user_platform_roles(user, [PlatformRoles.get_role(:institution_instructor)])

    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

    conn =
      conn
      |> Plug.Test.init_test_session(lti_session: nil)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, %{conn: conn, instructor: instructor, section: section}}
  end
end

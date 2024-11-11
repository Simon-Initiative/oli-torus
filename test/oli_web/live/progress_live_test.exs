defmodule OliWeb.ProgressLiveTest do
  use ExUnit.Case, async: true
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
      student: student
    } do
      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{student.id}%2F#{resource.id}&section=#{section.slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_resource]

    test "redirects to new session when accessing the student resource view", %{
      conn: conn,
      section: section,
      resource: resource,
      student: student
    } do
      conn = get(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{student.id}%2F#{resource.id}&amp;section=#{section.slug}"

      assert conn
             |> get(live_view_student_resource_route(section.slug, student.id, resource.id))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "student resource" do
    setup [:admin_conn, :create_resource]

    test "renders resource progress page correctly", %{
      conn: conn,
      section: section,
      resource: resource,
      student: student
    } do
      {:ok, _view, html} =
        live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

      assert html =~ "Details"
      assert html =~ "Attempt History"
    end

    scores_expected_format = %{
      7.239 => 7.24,
      4.876 => 4.88,
      5.22222 => 5.22,
      6.10 => 6.10,
      4 => 4.0,
      0.0 => 0.0,
      0 => 0.0
    }

    for {score, expected_score} <- scores_expected_format do
      @score score
      @expected_score expected_score

      test "loads student progress score correctly for #{score}", %{
        conn: conn,
        section: section,
        resource: resource,
        student: student
      } do
        insert(:resource_access,
          user: student,
          resource: resource,
          section: section,
          score: @score,
          out_of: 10.0
        )

        {:ok, view, _html} =
          live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

        assert view
               |> element("input[name=\"resource_access[score]\"]")
               |> render =~ "value=\"#{@expected_score}\""
      end
    end

    test "loads attempt history score correctly", %{
      conn: conn,
      section: section,
      resource: resource,
      revision: revision,
      student: student
    } do
      first_attempt = %{score: 5.2222, formatted: 5.22}
      second_attempt = %{score: 4.876, formatted: 4.88}
      third_attempt = %{score: 7.239, formatted: 7.24}
      out_of = 10.0

      resource_access =
        insert(:resource_access,
          user: student,
          resource: resource,
          section: section,
          score: third_attempt.score,
          out_of: out_of
        )

      date_now = DateTime.utc_now()

      attempt_1 =
        insert(:resource_attempt,
          revision: revision,
          resource_access: resource_access,
          score: first_attempt.score,
          out_of: out_of,
          lifecycle_state: "evaluated",
          date_submitted: date_now,
          date_evaluated: date_now
        )

      attempt_2 =
        insert(:resource_attempt,
          revision: revision,
          resource_access: resource_access,
          score: second_attempt.score,
          out_of: out_of,
          lifecycle_state: "evaluated",
          date_submitted: date_now,
          date_evaluated: date_now
        )

      attempt_3 =
        insert(:resource_attempt,
          revision: revision,
          resource_access: resource_access,
          score: third_attempt.score,
          out_of: out_of,
          lifecycle_state: "evaluated",
          date_submitted: date_now,
          date_evaluated: date_now
        )

      {:ok, view, _html} =
        live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

      assert view
             |> element(".list-group .list-group-item:nth-child(1)")
             |> render =~ "Attempt #{attempt_1.attempt_number}"

      assert view
             |> element(".list-group .list-group-item:nth-child(2)")
             |> render =~ "Attempt #{attempt_2.attempt_number}"

      assert view
             |> element(".list-group .list-group-item:nth-child(3)")
             |> render =~ "Attempt #{attempt_3.attempt_number}"

      assert has_element?(view, "span", "#{first_attempt.formatted} / #{out_of}")
      assert has_element?(view, "span", "#{second_attempt.formatted} / #{out_of}")
      assert has_element?(view, "span", "#{third_attempt.formatted} / #{out_of}")
    end
  end

  describe "admin breadcrumbs" do
    setup [:admin_conn, :create_resource]

    test "manual grading view", %{
      conn: conn,
      section: section
    } do
      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, section.slug)
        )

      {:ok, _view, html} = live(conn)

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "Manual Scoring"
    end

    test "student view", %{
      conn: conn,
      section: section,
      student: student
    } do
      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, student.id)
        )

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""
      assert html =~ "Student Progress"
    end

    test "student resource view", %{
      conn: conn,
      section: section,
      student: student,
      resource: resource
    } do
      {:ok, _view, html} =
        live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""

      assert html =~
               "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, student.id)}\""

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
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, section.slug)
        )

      {:ok, _view, html} = live(conn)

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""

      assert html =~
               "<a href=\"#{~p"/sections/#{section.slug}/manage"}\""

      assert html =~ "Manual Scoring"
    end

    test "student view", %{
      conn: conn,
      section: section,
      student: student
    } do
      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, student.id)
        )

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""

      assert html =~
               "<a href=\"#{~p"/sections/#{section.slug}/manage"}\""

      assert html =~ "Student Progress"
    end

    test "student resource view", %{
      conn: conn,
      section: section,
      student: student,
      resource: resource
    } do
      {:ok, _view, html} =
        live(conn, live_view_student_resource_route(section.slug, student.id, resource.id))

      assert html =~ "<nav class=\"breadcrumb-bar"
      refute html =~ "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)}\""

      assert html =~
               "<a href=\"#{~p"/sections/#{section.slug}/manage"}\""

      assert html =~
               "<a href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, section.slug, student.id)}\""

      assert html =~ "View Resource Progress"
    end
  end

  def create_resource(_context) do
    instructor = insert(:user)
    project = insert(:project, authors: [instructor.author])
    section = insert(:section, type: :enrollable)

    section_project_publication =
      insert(:section_project_publication, %{section: section, project: project})

    revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        graded: true
      )

    section_resource =
      insert(:section_resource, %{
        section: section,
        project: project,
        resource_id: revision.resource.id
      })

    Sections.update_section(section, %{root_section_resource_id: section_resource.id})

    insert(:published_resource, %{
      resource: revision.resource,
      revision: revision,
      publication: section_project_publication.publication,
      author: instructor.author
    })

    student = insert(:user)

    {:ok,
     section: section,
     resource: revision.resource,
     revision: revision,
     instructor: instructor,
     student: student}
  end

  defp setup_instructor_session(%{conn: conn, instructor: user, section: section}) do
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

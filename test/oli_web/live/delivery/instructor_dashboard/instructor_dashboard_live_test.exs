defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.InstructorDashboard
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  defp instructor_dashboard_path(section_slug, view) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      view
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end

    test "ensures instructors have access to the top navigation menu bar on vertical scroll", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :overview))

      assert view
             |> has_element?(".bg-delivery-instructor-dashboard-header.sticky.top-0")
    end

    test "if enrolled, can access the overview page with the course content tab as the default tab",
         %{
           instructor: instructor,
           section: section,
           conn: conn
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :overview))

      assert has_element?(view, "a.active", "Course Content")
      assert has_element?(view, "a", "Students")
      refute has_element?(view, "a.active", "Students")
      assert has_element?(view, "a", "Assessment Scores")
      refute has_element?(view, "a.active", "Assessment Scores")
      assert has_element?(view, "a", "Recommended Actions")
      refute has_element?(view, "a.active", "Recommended Actions")
    end

    test "if enrolled, can access the insights page with the dashboard tab as the default tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      insights_path = instructor_dashboard_path(section.slug, :insights)

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, insights_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
      assert has_element?(view, "#learning-dashboard")
      assert has_element?(view, "a", "Content")
      refute has_element?(view, "a.active", "Content")
      assert has_element?(view, "a", "Learning Objectives")
      refute has_element?(view, "a.active", "Learning Objectives")
      assert has_element?(view, "a", "Scored Pages")
      refute has_element?(view, "a.active", "Scored Pages")
      assert has_element?(view, "a", "Practice Pages")
      refute has_element?(view, "a.active", "Practice Pages")
      assert has_element?(view, "a", "Surveys")
      refute has_element?(view, "a.active", "Surveys")
    end

    test "bare insights entry restores persisted dashboard scope and canonicalizes the url", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      insights_path = instructor_dashboard_path(section.slug, :insights)

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, insights_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(
               view,
               "#dashboard_scope option[selected][value='container:#{container.id}']"
             )
    end

    test "if enrolled, can access the insights dashboard tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
      assert has_element?(view, "#learning-dashboard-runtime-status")
      assert has_element?(view, "label[for='dashboard_scope']", "Scope")

      assert has_element?(
               view,
               "#dashboard_scope option[selected][value='course']",
               "Course (all content)"
             )
    end

    test "dashboard entry without persisted scope patches to the default course scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "#dashboard_scope option[selected][value='course']")
    end

    test "dashboard entry with an invalid persisted scope falls back to the default course scope",
         %{
           instructor: instructor,
           section: section,
           conn: conn
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:999999"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
    end

    test "dashboard entry with an invalid url scope canonicalizes to the default course scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      invalid_dashboard_path =
        ~p"/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=inexistente"

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, invalid_dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
    end

    test "root instructor dashboard route redirects to insights dashboard", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn = get(conn, ~p"/sections/#{section.slug}/instructor_dashboard")

      assert redirected_to(conn) ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard"
    end

    test "if enrolled, can access the mange page", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/manage")

      assert has_element?(view, "div", "Overview of course section details")
    end

    test "if enrolled, can access the discussion activity page", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :discussions))

      assert has_element?(view, "h4", "Discussion Activity")
    end

    test "user is sent to the dashboard tab if an invalid tab is provided in the url param",
         %{
           conn: conn,
           instructor: instructor,
           section: section
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      invalid_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          "invalid_tab",
          %{}
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, invalid_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
    end

    test "restores and persists the last viewed dashboard scope for the instructor enrollment", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(
               view,
               "#dashboard_scope option[selected][value='container:#{container.id}']"
             )

      view
      |> form("form[phx-change=dashboard_scope_changed]")
      |> render_change(%{scope: "course"})

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "course"
    end

    test "invalid scope changes fall back to course without overwriting persisted state", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> form("form[phx-change=dashboard_scope_changed]")
      |> render_change(%{scope: "container:999999"})

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
      )

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "container:#{container.id}"
    end
  end
end

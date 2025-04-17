defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

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
             |> has_element?(".bg-delivery-instructor-dashboard-header.sticky.top-0.z-50")
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
      assert has_element?(view, "a", "Quiz Scores")
      refute has_element?(view, "a.active", "Quiz Scores")
      assert has_element?(view, "a", "Recommended Actions")
      refute has_element?(view, "a.active", "Recommended Actions")
    end

    test "if enrolled, can access the insights page with the content tab as the default tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :insights))

      assert has_element?(view, "a.active", "Content")
      assert has_element?(view, "a", "Learning Objectives")
      refute has_element?(view, "a.active", "Learning Objectives")
      assert has_element?(view, "a", "Scored Activities")
      refute has_element?(view, "a.active", "Scored Activities")
      assert has_element?(view, "a", "Practice Activities")
      refute has_element?(view, "a.active", "Practice Activities")
      assert has_element?(view, "a", "Surveys")
      refute has_element?(view, "a.active", "Surveys")
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

    test "user is sent to report/default_content_tab if an invalid tab is provided in the url param",
         %{
           conn: conn,
           instructor: instructor,
           section: section
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
            section.slug,
            :insights,
            "invalid_tab",
            %{}
          )
        )

      # content is the active tab
      assert has_element?(view, "a.active", "Content")
    end
  end
end

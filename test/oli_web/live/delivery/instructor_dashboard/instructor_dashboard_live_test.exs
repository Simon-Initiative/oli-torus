defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
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
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Foverview"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Freports"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :reports))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fmanage"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fdiscussions"

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
               live(conn, instructor_dashboard_path(section.slug, :reports))

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
               live(conn, instructor_dashboard_path(section.slug, :reports))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
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
      assert has_element?(view, "a", "Scored Activities")
      refute has_element?(view, "a.active", "Scored Activities")
      assert has_element?(view, "a", "Recommended Actions")
      refute has_element?(view, "a.active", "Recommended Actions")
    end

    test "if enrolled, can access the reports page with the content tab as the default tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :reports))

      assert has_element?(view, "a.active", "Content")
      assert has_element?(view, "a", "Students")
      refute has_element?(view, "a.active", "Students")
      assert has_element?(view, "a", "Learning Objectives")
      refute has_element?(view, "a.active", "Learning Objectives")
      assert has_element?(view, "a", "Quiz Scores")
      refute has_element?(view, "a.active", "Quiz Scores")
      assert has_element?(view, "a", "Course Discussion")
      refute has_element?(view, "a.active", "Course Discussion")
    end

    test "if enrolled, can access the mange page", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :manage))

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
  end
end

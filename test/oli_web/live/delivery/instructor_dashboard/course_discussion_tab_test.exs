defmodule OliWeb.Delivery.InstructorDashboard.CourseDiscussionTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_course_discussion_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :course_discussion
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fcourse_discussion"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_course_discussion_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_course_discussion_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_course_discussion_route(section.slug))
    end

    test "can access page if enrolled to section without a collab space configured", %{
      instructor: instructor,
      conn: conn
    } do
      {:ok, %{section: section}} = section_with_assessment_without_collab_space(%{})
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_course_discussion_route(section.slug))

      # Course Discussion tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_course_discussion_route(section.slug)}"].border-b-2},
               "Course Discussion"
             )

      # Course Discussion tab content gets rendered, but there is no collab space config
      assert render(view) =~ "There is no collaboration space configured for this Course"
    end

    test "can access page if enrolled to section with a collab space configured", %{
      instructor: instructor,
      conn: conn,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_course_discussion_route(section.slug))

      # Course Discussion tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_course_discussion_route(section.slug)}"].border-b-2},
               "Course Discussion"
             )

      # Course Discussion tab content gets rendered with the collab space view
      assert render(view) =~ "Course Discussion"
      assert has_element?(view, "#course_discussion")
    end
  end
end

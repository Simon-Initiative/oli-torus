defmodule OliWeb.Delivery.InstructorDashboard.QuizScoreTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_quiz_scores_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :reports,
      :quiz_scores,
      params
    )
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Freports%2Fquiz_scores"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_quiz_scores_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "cannot access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_quiz_scores_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_quiz_scores_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug))

      # QuizScores tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_quiz_scores_route(section.slug)}"].border-b-2},
               "Quiz Scores"
             )

      # QuizScores tab content gets rendered
      assert has_element?(view, "h6", "There are no quiz scores to show")
    end
  end

  describe "quiz scores" do
    setup [:instructor_conn, :section_with_gating_conditions]

    test "loads correctly when there are no quiz scores", %{
      conn: conn,
      instructor: instructor
    } do
      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(nil)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug))

      assert has_element?(view, "h6", "There are no quiz scores to show")
    end

    test "loads correctly when a student has not yet finished a quiz", %{
      conn: conn,
      section: section,
      instructor: instructor,
      student_with_gating_condition: student,
      graded_page_1: graded_page_1
    } do
      insert(:resource_access,
        user: student,
        section: section,
        resource: graded_page_1.resource,
        score: nil,
        out_of: nil
      )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug))

      assert has_element?(view, "h4", "Quiz Scores")
    end

    test "applies searching", %{
      conn: conn,
      section: section,
      instructor: instructor
    } do
      student = insert(:user, %{family_name: "Example", given_name: "Student1"})
      student_2 = insert(:user, %{family_name: "Example", given_name: "Student2"})
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      params = %{
        text_search: student.given_name
      }

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug, params))

      assert has_element?(
               view,
               "div",
               "#{student.family_name}, #{student.given_name}"
             )

      refute has_element?(
               view,
               "div",
               "#{student_2.family_name}, #{student_2.given_name}"
             )
    end

    test "applies sorting", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      student = insert(:user, %{family_name: "Example", given_name: "Student1"})
      student_2 = insert(:user, %{family_name: "Example", given_name: "Student2"})
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug, params))

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ student_2.family_name

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ student.family_name
    end

    test "applies pagination", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      student = insert(:user, %{family_name: "Example", given_name: "Student1"})
      student_2 = insert(:user, %{family_name: "Example", given_name: "Student2"})
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      params = %{
        offset: 1,
        limit: 1
      }

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug, params))

      assert has_element?(
               view,
               ~s{nav[aria-label="Paging"]}
             )
    end
  end
end

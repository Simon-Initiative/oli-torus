defmodule OliWeb.Delivery.StudentDashboard.Components.QuizzScoresTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_dashboard_route(
         section_slug,
         student_id,
         :quizz_scores,
         params \\ %{}
       ) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      :quizz_scores,
      params
    )
  end

  defp insert_resource_access(page1, page3, page5, section, user1) do
    # Page 1
    insert(:resource_access,
      user: user1,
      section: section,
      resource: page1.resource,
      score: 5,
      out_of: 10
    )

    # Page 3
    insert(:resource_access,
      user: user1,
      section: section,
      resource: page3.resource,
      score: 7,
      out_of: 10
    )

    # Page 5
    insert(:resource_access,
      user: user1,
      section: section,
      resource: page5.resource,
      score: 2,
      out_of: 10
    )
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fstudent_dashboard%2F#{student.id}%2Fquizz_scores"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_dashboard_route(section.slug, student.id, :quizz_scores)
               )
    end
  end

  describe "student" do
    setup [:user_conn]

    test "cannot access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_dashboard_route(section.slug, user.id, :quizz_scores)
               )
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      student = insert(:user)
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_dashboard_route(section.slug, student.id, :quizz_scores)
               )
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      student = insert(:user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :quizz_scores))

      # QuizScores tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :quizz_scores)}"].border-b-2},
               "Quiz Scores"
             )

      # QuizScores tab content gets rendered
      assert has_element?(view, "h6", "There are no quiz scores to show")
    end
  end

  describe "Quizz Scores tab" do
    setup [:instructor_conn, :section_with_gating_conditions]

    test "gets rendered correctly", %{
      conn: conn,
      instructor: instructor
    } do
      student = insert(:user)

      {:ok,
       section: section, unit_one_revision: _unit_one_revision, page_revision: _page_revision} =
        section_with_assessment(nil)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :quizz_scores))

      # Quizz Scores tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :quizz_scores)}"].border-b-2},
               "Quiz Scores"
             )

      assert has_element?(view, "h6", "There are no quiz scores to show")
    end

    test "applies searching", %{
      conn: conn,
      section: section,
      instructor: instructor,
      student_with_gating_condition: student_with_gating_condition,
      graded_page_1: graded_page_1,
      graded_page_3: graded_page_3,
      graded_page_5: graded_page_5
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_3,
        graded_page_5,
        section,
        student_with_gating_condition
      )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores
          )
        )

      assert has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_5.title}"
             )

      # searching by student
      params = %{
        text_search: graded_page_3.title
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores,
            params
          )
        )

      refute has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_5.title}"
             )
    end

    test "applies sorting", %{
      conn: conn,
      instructor: instructor,
      section: section,
      student_with_gating_condition: student_with_gating_condition,
      graded_page_1: graded_page_1,
      graded_page_3: graded_page_3,
      graded_page_5: graded_page_5
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_3,
        graded_page_5,
        section,
        student_with_gating_condition
      )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores
          )
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ graded_page_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ graded_page_3.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(3)")
             |> render() =~ graded_page_5.title

      ## sorting by student
      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores,
            params
          )
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ graded_page_5.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ graded_page_3.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(3)")
             |> render() =~ graded_page_1.title
    end

    test "applies pagination", %{
      conn: conn,
      instructor: instructor,
      section: section,
      student_with_gating_condition: student_with_gating_condition,
      graded_page_1: graded_page_1,
      graded_page_3: graded_page_3,
      graded_page_5: graded_page_5
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_3,
        graded_page_5,
        section,
        student_with_gating_condition
      )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores
          )
        )

      assert has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_5.title}"
             )

      ## aplies limit
      params = %{
        limit: 1,
        sort_order: "asc"
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores,
            params
          )
        )

      assert has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_5.title}"
             )

      ## aplies pagination
      params = %{
        limit: 1,
        offset: 1
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student_with_gating_condition.id,
            :quizz_scores,
            params
          )
        )

      refute has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_5.title}"
             )
    end
  end
end

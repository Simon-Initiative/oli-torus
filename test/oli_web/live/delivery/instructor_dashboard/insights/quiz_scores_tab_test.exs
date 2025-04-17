defmodule OliWeb.Delivery.InstructorDashboard.QuizScoreTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_quiz_scores_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :quiz_scores,
      params
    )
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

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
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: _page_revision,
       page_2_revision: _page_2_revision} =
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
      student_1 = insert(:user, %{family_name: "Smith", given_name: "Adam"})
      student_2 = insert(:user, %{family_name: "Lee", given_name: "Bob"})
      student_3 = insert(:user, %{family_name: "Zisk", given_name: "Tom"})
      Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug, params))

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(1)")
             |> render() =~ student_3.family_name

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ student_1.family_name

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(3)")
             |> render() =~ student_2.family_name
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

  describe "page size change" do
    setup [:instructor_conn, :section_with_gating_conditions]

    test "lists table elements according to the default page size", %{
      conn: conn,
      instructor: instructor,
      section: section,
      student_with_gating_condition: student_1,
      student_with_gating_condition_2: student_2
    } do
      student_3 = insert(:user, %{family_name: "Lee", given_name: "Bob"})
      student_4 = insert(:user, %{family_name: "Smith", given_name: "Adam"})
      student_5 = insert(:user, %{family_name: "Zisk", given_name: "Tom"})
      Sections.enroll(student_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_5.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug))

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(1)",
               student_1.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(2)",
               student_2.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(3)",
               student_3.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(4)",
               student_4.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(5)",
               student_5.family_name
             )

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    test "updates page size and list expected elements", %{
      conn: conn,
      instructor: instructor,
      section: section,
      student_with_gating_condition: student_1,
      student_with_gating_condition_2: student_2
    } do
      student_3 = insert(:user, %{family_name: "Lee", given_name: "Bob"})
      student_4 = insert(:user, %{family_name: "Smith", given_name: "Adam"})
      student_5 = insert(:user, %{family_name: "Zisk", given_name: "Tom"})
      Sections.enroll(student_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_5.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_quiz_scores_route(section.slug))

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      # Page 1
      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(1)",
               student_1.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(2)",
               student_2.family_name
             )

      # Page 2
      refute has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(3)",
               student_3.family_name
             )

      refute has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(4)",
               student_4.family_name
             )

      # Page 3
      refute has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(5)",
               student_5.family_name
             )
    end

    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      student_3 = insert(:user, %{family_name: "Lee", given_name: "Bob"})
      student_4 = insert(:user, %{family_name: "Smith", given_name: "Adam"})
      student_5 = insert(:user, %{family_name: "Zisk", given_name: "Tom"})
      Sections.enroll(student_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_5.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_quiz_scores_route(section.slug, %{
            limit: 2,
            offset: 2
          })
        )

      # Page 2
      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(1)",
               student_3.family_name
             )

      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(2)",
               student_4.family_name
             )

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      # Page 3. It keeps showing the same element.
      assert has_element?(
               view,
               "table.instructor_dashboard_table > tbody > tr:nth-child(1)",
               student_3.family_name
             )
    end
  end
end

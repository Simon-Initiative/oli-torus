defmodule OliWeb.Delivery.StudentDashboard.Components.LearningObjectivesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_dashboard_route(
         section_slug,
         student_id,
         tab,
         params \\ %{}
       ) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      tab,
      params
    )
  end

  defp enrolled_student_and_instructor(%{section: section, instructor: instructor}) do
    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    %{student: student}
  end

  describe "Learning Objectives tab" do
    setup [:instructor_conn, :create_project_with_objectives, :enrolled_student_and_instructor]

    test "gets rendered correctly", %{
      section: section,
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      # Learning Objectives tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)}"].border-b-2},
               "Learning Objectives"
             )

      assert has_element?(view, "h4", "Learning Objectives")
    end

    test "loads correctly when there are no objectives", %{
      conn: conn,
      instructor: instructor,
      student: student
    } do
      section =
        insert(:section,
          open_and_free: true,
          type: :enrollable
        )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      refute has_element?(view, "#objectives-table")
      assert has_element?(view, "h6", "There are no objectives to show")
    end

    test "applies searching", %{
      conn: conn,
      student: student,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## searching by objective
      params = %{
        text_search: "Objective 1"
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "applies sorting", %{
      conn: conn,
      student: student,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ obj_revision_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ obj_revision_2.title

      ## sorting by objective
      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ obj_revision_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ obj_revision_1.title
    end

    test "applies pagination", %{
      conn: conn,
      student: student,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        limit: 1
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        offset: 1
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      refute has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "filtering by container", %{
      conn: conn,
      student: student,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2,
      module_revision: module_revision
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies filtering by module container
      params = %{
        filter_by: module_revision.resource_id
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      refute has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies filtering by root container
      params = %{
        filter_by: "all"
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(
            section.slug,
            student.id,
            :learning_objectives,
            params
          )
        )

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")
    end
  end
end

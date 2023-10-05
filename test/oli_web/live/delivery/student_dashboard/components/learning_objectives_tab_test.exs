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
      Sections.update_section(section, %{v25_migration: :not_started})

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
      Sections.update_section(section, %{v25_migration: :not_started})

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
      Sections.update_section(section, %{v25_migration: :not_started})

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
  end

  describe "objectives filtering" do
    setup [
      :instructor_conn,
      :create_full_project_with_objectives,
      :enrolled_student_and_instructor
    ]

    ## Course Hierarchy
    #
    # Root Container --> Page 1 --> Activity X
    #                |--> Unit Container --> Module Container 1 --> Page 2 --> Activity Y
    #                |                                                     |--> Activity Z
    #                |--> Module Container 2 --> Page 3 --> Activity W
    #
    ## Objectives Hierarchy
    #
    # Page 1 --> Objective A
    # Page 2 --> Objective B
    #
    # Note: the objectives above are not considered since they are attached to the pages
    #
    # Activity Y --> Objective C
    #           |--> SubObjective C1
    # Activity Z --> Objective D
    # Activity W --> Objective E
    #           |--> Objective F
    #
    # Note: Activity X does not have objectives
    test "applies filtering by module when contained objectives were created", %{
      conn: conn,
      student: student,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "#objectives-table")

      refute has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      ## searching by Unit Container
      params = %{
        filter_by: revisions.unit_revision.resource_id
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

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      ## searching by Module Container 2
      params = %{
        filter_by: revisions.module_revision_2.resource_id
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

      assert has_element?(view, "#objectives-table")
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Does not have info tooltip
      refute has_element?(view, "#filter-disabled-tooltip")
      # Select is enabled
      refute has_element?(view, ".torus-select[disabled]")
    end

    test "does not allow filtering by module when contained objectives were not created", %{
      conn: conn,
      student: student,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "#objectives-table")

      # It contains objectives attached to pages but not to activities
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Has info tooltip
      assert has_element?(view, "#filter-disabled-tooltip")
      # Select is disabled
      assert has_element?(view, ".torus-select[disabled]")
    end

    test "does not allow filtering by module when section has the wrong migration status", %{
      conn: conn,
      student: student,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.rebuild_contained_objectives(section)
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Has info tooltip
      assert has_element?(view, "#filter-disabled-tooltip")
      # Select is disabled
      assert has_element?(view, ".torus-select[disabled]")
    end
  end
end

defmodule OliWeb.Delivery.StudentDashboard.Components.LearningObjectivesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
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

    test "renders subobjectives", %{
      section: section,
      conn: conn,
      student: student,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2,
      project: project,
      publication: publication
    } do
      %{authors: [author]} = project
      # Creating subobjectives
      [subobj_rev_1, subobj_rev_2, subobj_rev_3] =
        for index <- ["1", "3", "2"] do
          subobj_resource = insert(:resource)

          subobj_revision =
            insert(:revision,
              resource: subobj_resource,
              resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
              slug: "subobjective_#{index}",
              title: "Sub_Objective #{index}"
            )

          insert(:project_resource, project_id: project.id, resource_id: subobj_resource.id)

          insert(:published_resource,
            publication: publication,
            resource: subobj_resource,
            revision: subobj_revision
          )

          subobj_revision
        end

      # Attaching subobjectives to objective
      {:ok, _obj_revision_1} =
        Oli.Resources.update_revision(obj_revision_1, %{
          children: [subobj_rev_1.resource_id, subobj_rev_2.resource_id, subobj_rev_3.resource_id],
          author_id: author.id
        })

      # Publishing the project
      {:ok, _publication} = Oli.Publishing.update_publication(publication, %{published: nil})
      {:ok, publication} = Oli.Publishing.publish_project(project, "some changes", author.id)
      Sections.update_section_project_publication(section, project.id, publication.id)
      Sections.rebuild_section_resources(section: section, publication: publication)

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives)
        )

      # Row 1
      assert [obj_revision_1.title, "-"] == pull_data_from_table(view, 1)
      # Row 2
      assert [obj_revision_2.title, "-"] == pull_data_from_table(view, 2)
      # Row 3 - has subobjective 1
      assert [obj_revision_1.title, subobj_rev_1.title] == pull_data_from_table(view, 3)
      # Row 4 - has subobjective 2 (We also check here the order)
      assert [obj_revision_1.title, subobj_rev_3.title] == pull_data_from_table(view, 4)
      # Row 5 - has subobjective 2 (We also check here the order)
      assert [obj_revision_1.title, subobj_rev_2.title] == pull_data_from_table(view, 5)
    end

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
    @tag :skip
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

  describe "page size change" do
    setup [
      :instructor_conn,
      :create_full_project_with_objectives,
      :enrolled_student_and_instructor
    ]

    test "lists table elements according to the default page size", %{
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

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    @tag :skip
    test "updates page size and list expected elements", %{
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

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      # Page 1
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 2 and 3
      refute has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")
    end

    @tag :skip
    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      student: student,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.rebuild_contained_objectives(section)

      # Starts in page 2
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_dashboard_route(section.slug, student.id, :learning_objectives, %{
            limit: 2,
            offset: 2
          })
        )

      # Page 1
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 2
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      # Page 3
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      # Page 1
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      # Page 2
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 3. It keeps showing the same element.
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      # Page 4
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      # Page 5
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from 1 to 3
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "3"})

      # Page 1. Still showing the same element.
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      # Page 2
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")
    end
  end

  defp pull_data_from_table(view, row) do
    col_1 =
      view
      |> element(
        "table.instructor_dashboard_table > tbody > tr:nth-child(#{row}) [data-proficiency-check='true'] > span:last-child"
      )
      |> render()
      |> Floki.parse_document!()
      |> Floki.text()

    col_2 =
      view
      |> element(
        "table.instructor_dashboard_table > tbody > tr:nth-child(#{row}) > td:nth-child(2) > div > div"
      )
      |> render()
      |> Floki.parse_document!()
      |> Floki.text()

    [col_1, col_2]
  end
end

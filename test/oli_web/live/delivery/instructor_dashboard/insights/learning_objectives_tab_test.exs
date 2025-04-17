defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectivesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_learning_objectives_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :insights,
      :learning_objectives,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :create_project_with_objectives]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      # LearningObjectives tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_learning_objectives_route(section.slug)}"].border-b-2},
               "Learning Objectives"
             )

      # LearningObjectives tab content gets rendered
      assert has_element?(view, "h4", "Learning Objectives")
    end
  end

  describe "objectives" do
    setup [:instructor_conn, :create_project_with_objectives]

    test "loads correctly when there are no objectives", %{
      conn: conn,
      instructor: instructor
    } do
      section =
        insert(:section,
          open_and_free: true,
          type: :enrollable
        )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      refute has_element?(view, "#objectives-table")
      assert has_element?(view, "h6", "There are no objectives to show")
    end

    test "applies searching", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## searching by objective
      params = %{
        text_search: "Objective 1"
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "applies sorting", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

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

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ obj_revision_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ obj_revision_1.title
    end

    test "applies pagination", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        limit: 1
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        offset: 1
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      refute has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "display proficiency distribution", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(
               view,
               "#proficiency-data-bar-chart-for-objective-#{obj_revision_1.resource_id}"
             )

      assert has_element?(
               view,
               "#proficiency-data-bar-chart-for-objective-#{obj_revision_2.resource_id}"
             )
    end
  end

  describe "objectives filtering" do
    setup [:instructor_conn, :create_full_project_with_objectives]
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
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

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

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

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

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

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
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Has info tooltip
      assert has_element?(view, "#filter-disabled-tooltip")
      # Select is disabled
      assert has_element?(view, ".torus-select[disabled]")
    end

    test "filter by proficiency works correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      ## Checks that all objectives are displayed
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")

      ## Set proficiency filter to Low
      params = %{
        selected_proficiency_ids: Jason.encode!([1])
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))
      ## Checks that there are no objectives displayed since none of them have proficiency Low
      assert has_element?(view, "h6", "There are no objectives to show")

      ## Click on Clear All Filters button
      element(view, "button[phx-click=\"clear_all_filters\"]") |> render_click()

      ## Checks that all objectives are displayed again
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
    end
  end

  describe "page size change" do
    setup [:instructor_conn, :create_full_project_with_objectives]

    test "lists table elements according to the default page size", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
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
      section: section,
      instructor: instructor,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

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
      section: section,
      instructor: instructor,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      # Starts in page 2
      {:ok, view, _html} =
        live(
          conn,
          live_view_learning_objectives_route(section.slug, %{
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
end

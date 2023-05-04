defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectivesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_learning_objectives_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :learning_objectives,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Flearning_objectives"

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

    test "filtering by container", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2,
      module_revision: module_revision
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies filtering by module container
      params = %{
        filter_by: module_revision.resource_id
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      refute has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies filtering by root container
      params = %{
        filter_by: "all"
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")
    end
  end
end

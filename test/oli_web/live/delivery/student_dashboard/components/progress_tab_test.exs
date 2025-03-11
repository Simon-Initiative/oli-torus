defmodule OliWeb.Delivery.StudentDashboard.Components.ProgressTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_progress_route(
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
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_progress_route(section.slug, student.id, :progress)
               )
    end
  end

  describe "student" do
    setup [:user_conn]

    test "cannot access page", %{user: user, conn: conn} do
      section = insert(:section)
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_progress_route(section.slug, user.id, :progress)
               )
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_without_pages]

    test "cannot access page if not enrolled to section", %{
      conn: conn,
      section: section
    } do
      student = insert(:user)
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_progress_route(section.slug, student.id, :progress)
               )
    end

    test "can access page if enrolled to section", %{
      conn: conn,
      section: section,
      instructor: instructor
    } do
      student = insert(:user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(section.slug, student.id, :progress)
        )

      # Progress tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_progress_route(section.slug, student.id, :progress)}"].border-b-2},
               "Progress"
             )

      # Progress tab content gets rendered
      assert has_element?(view, "h6", "There are no progress to show")
    end
  end

  describe "Progress tab" do
    setup [:instructor_conn, :section_with_gating_conditions, :enrolled_student_and_instructor]

    test "gets rendered correctly", %{
      section: section,
      conn: conn,
      student: student,
      graded_page_1: graded_page_1,
      graded_page_2: graded_page_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_progress_route(section.slug, student.id, :progress))

      # Progress tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_progress_route(section.slug, student.id, :progress)}"].border-b-2},
               "Progress"
             )

      assert has_element?(view, "a", graded_page_1.title)
      assert has_element?(view, "a", graded_page_2.title)
    end

    test "applies searching", %{
      conn: conn,
      section: section,
      student: student,
      graded_page_1: graded_page_1,
      graded_page_2: graded_page_2,
      graded_page_3: graded_page_3
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_2,
        graded_page_3,
        section,
        student
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress
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
               "#{graded_page_2.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      # searching by student
      params = %{
        text_search: graded_page_2.title
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress,
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
               "#{graded_page_2.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )
    end

    test "applies sorting", %{
      conn: conn,
      section: section,
      student: student,
      graded_page_1: graded_page_1,
      graded_page_2: graded_page_2,
      graded_page_3: graded_page_3,
      graded_page_4: graded_page_4,
      graded_page_5: graded_page_5,
      graded_page_6: graded_page_6
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_2,
        graded_page_3,
        section,
        student
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress
          )
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ graded_page_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ graded_page_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(3)")
             |> render() =~ graded_page_3.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(4)")
             |> render() =~ graded_page_4.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(5)")
             |> render() =~ graded_page_5.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:last-child")
             |> render() =~ graded_page_6.title

      ## sorting by student
      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress,
            params
          )
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:last-child")
             |> render() =~ graded_page_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(5)")
             |> render() =~ graded_page_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(4)")
             |> render() =~ graded_page_3.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(3)")
             |> render() =~ graded_page_4.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ graded_page_5.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ graded_page_6.title
    end

    test "applies pagination", %{
      conn: conn,
      section: section,
      student: student,
      graded_page_1: graded_page_1,
      graded_page_2: graded_page_2,
      graded_page_3: graded_page_3
    } do
      insert_resource_access(
        graded_page_1,
        graded_page_2,
        graded_page_3,
        section,
        student
      )

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress
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
               "#{graded_page_2.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      ## aplies limit
      params = %{
        limit: 2,
        sort_order: "asc"
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress,
            params
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
               "#{graded_page_2.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )

      ## aplies pagination
      params = %{
        limit: 2,
        offset: 2,
        sort_order: "asc"
      }

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(
            section.slug,
            student.id,
            :progress,
            params
          )
        )

      refute has_element?(
               view,
               "div",
               "#{graded_page_1.title}"
             )

      refute has_element?(
               view,
               "div",
               "#{graded_page_2.title}"
             )

      assert has_element?(
               view,
               "div",
               "#{graded_page_3.title}"
             )
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
      {:ok, view, _html} =
        live(conn, live_view_students_progress_route(section.slug, student.id, :progress))

      assert has_element?(view, "a", revisions.page_revision_1.title)
      assert has_element?(view, "a", revisions.page_revision_2.title)
      assert has_element?(view, "a", revisions.page_revision_3.title)

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    test "updates page size and list expected elements", %{
      conn: conn,
      section: section,
      student: student,
      revisions: revisions
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_progress_route(section.slug, student.id, :progress))

      assert has_element?(view, "a", revisions.page_revision_1.title)
      assert has_element?(view, "a", revisions.page_revision_2.title)
      assert has_element?(view, "a", revisions.page_revision_3.title)

      # Change page size from default (20) to 2
      view
      |> element("#header_paging_page_size_form")
      |> render_change(%{limit: "2"})

      # Page 1
      assert has_element?(view, "a", revisions.page_revision_1.title)
      assert has_element?(view, "a", revisions.page_revision_2.title)
      # Page 2
      refute has_element?(view, "a", revisions.page_revision_3.title)
    end

    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      section: section,
      student: student,
      revisions: revisions
    } do
      # Starts in page 2
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_progress_route(section.slug, student.id, :progress, %{
            limit: 2,
            offset: 2
          })
        )

      # Page 1
      refute has_element?(view, "a", revisions.page_revision_1.title)
      refute has_element?(view, "a", revisions.page_revision_2.title)
      # Page 2
      assert has_element?(view, "a", revisions.page_revision_3.title)

      # Change page size from 2 to 1
      view
      |> element("#header_paging_page_size_form")
      |> render_change(%{limit: "1"})

      # Page 1
      refute has_element?(view, "a", revisions.page_revision_1.title)
      # Page 2
      refute has_element?(view, "a", revisions.page_revision_2.title)
      # Page 3. It keeps showing the same element.
      assert has_element?(view, "a", revisions.page_revision_3.title)
    end
  end
end

defmodule OliWeb.Delivery.InstructorDashboard.StudentsTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

  defp live_view_students_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :students,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fstudents"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      user = insert(:user)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      # Students tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_route(section.slug)}"].border-b-2},
               "Students"
             )

      # Students table gets rendered
      assert has_element?(view, "h4", "Students")

      assert render(view) =~
               OliWeb.Common.Utils.name(user.name, user.given_name, user.family_name)
    end

    test "students table gets rendered considering the given url params", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section, mod1_pages: mod1_pages, mod1_resource: mod1_resource} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 0.9)
      set_progress(section.id, page_1.published_resource.resource_id, user_2.id, 0.6)
      set_progress(section.id, page_1.published_resource.resource_id, user_3.id, 0)
      set_progress(section.id, page_1.published_resource.resource_id, user_4.id, 0.3)

      ### sorting by student
      params = %{
        sort_order: :desc,
        sort_by: :name
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2, student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Di Maria, Angelito"
      assert student_for_tr_2 =~ "Jr, Neymar"
      assert student_for_tr_3 =~ "Suarez, Luis"
      assert student_for_tr_4 =~ "Messi, Lionel"

      ### text filtering
      params = %{
        text_search: "Messi"
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Messi, Lionel"

      assert element(view, "#students_search_input-input") |> render() =~ ~s'value="Messi"'

      refute render(view) =~ "Jr, Neymar"
      refute render(view) =~ "Suarez, Luis"
      refute render(view) =~ "Di Maria, Angelito"

      ### pagination
      params = %{
        offset: 2,
        limit: 2
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Jr, Neymar"
      assert student_for_tr_2 =~ "Di Maria, Angelito"

      assert element(view, "#header_paging div:first-child") |> render() =~
               "Showing result 3 - 4 of 4 total"

      assert element(view, "li.page-item.active a", "2")
      refute render(view) =~ "Suarez, Luis"
      refute render(view) =~ "Messi, Lionel"

      ### filtering by container
      params = %{container_id: mod1_resource.id}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["30%", "20%", "0%", "10%"]

      ### filtering by no container
      ### (we want to get the progress across all course section)
      params = %{container_id: nil}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["8%", "5%", "0%", "3%"]

      ### filtering by non existing container
      params = %{container_id: 99999}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["0%", "0%", "0%", "0%"]

      ### filtering by page
      params = %{page_id: page_1.published_resource.resource_id}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["90%", "60%", "0%", "30%"]
    end
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end
end

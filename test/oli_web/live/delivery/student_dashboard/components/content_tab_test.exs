defmodule OliWeb.Delivery.StudentDashboard.Components.ContentTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

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

  defp section_with_larger_hierarchy(_) do
    Oli.Seeder.base_project_with_larger_hierarchy()
  end

  defp enrolled_student_and_instructor(%{section: section, instructor: instructor}) do
    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    %{student: student}
  end

  defp set_student_metrics(%{student: student, section: section, mod1_pages: mod1_pages} = params) do
    [page_1, _page_2, _page_3] = mod1_pages
    {:ok, _} = Sections.rebuild_contained_pages(section)

    set_progress(section.id, page_1.published_resource.resource_id, student.id, 0.9)
    params
  end

  describe "Content tab" do
    setup [
      :instructor_conn,
      :section_with_larger_hierarchy,
      :enrolled_student_and_instructor,
      :set_student_metrics
    ]

    test "gets rendered correctly", %{
      section: section,
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content))

      # Content tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :content)}"].border-b-2},
               "Content"
             )

      assert has_element?(view, "button[id=\"filter_units_button\"]", "Units")
    end

    test "gets sorted by module through url query params", %{
      section: section,
      conn: conn,
      student: student
    } do
      params = %{
        sort_order: :desc,
        sort_by: :container_name,
        container_filter_by: :modules
      }

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content, params))

      [module_for_tr_1, module_for_tr_2, module_for_tr_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr})
        |> Enum.map(fn tr -> Floki.text(tr) end)

      assert module_for_tr_1 =~ "Module 3"
      assert module_for_tr_2 =~ "Module 2"
      assert module_for_tr_3 =~ "Module 1"
    end

    test "gets filtered by text through url query params", %{
      section: section,
      conn: conn,
      student: student
    } do
      params = %{
        text_search: "Module 2",
        container_filter_by: :modules
      }

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content, params))

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find(~s{.instructor_dashboard_table tbody tr td})
             |> Floki.text() =~ "Module 2"
    end

    test "gets paginated through url query params", %{
      section: section,
      conn: conn,
      student: student
    } do
      params = %{
        offset: 2,
        limit: 2,
        container_filter_by: :modules
      }

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content, params))

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find(~s{.instructor_dashboard_table tbody tr td})
             |> Floki.text() =~ "Module 3"

      assert element(view, "#footer_paging") |> render() =~ "Showing result 3 - 3 of 3 total"

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find(~s{li.page-item.active button})
             |> Floki.text() =~ "2"
    end

    test "gets filtered by module through url query params", %{
      section: section,
      conn: conn,
      student: student
    } do
      params = %{container_filter_by: :modules}

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["30%", "0%", "0%"]
    end

    test "gets filtered by unit through url query params", %{
      section: section,
      conn: conn,
      student: student
    } do
      params = %{container_filter_by: :units}

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["15%", "0%"]
    end

    test "both units and modules options are shown to user in dropdown", %{
      section: section,
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content))

      options_for_select =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="filter_container"]})
        |> Floki.attribute("phx-value-filter")

      assert options_for_select == ["units", "modules"]
    end
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end
end

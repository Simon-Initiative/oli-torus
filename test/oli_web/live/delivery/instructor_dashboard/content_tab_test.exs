defmodule OliWeb.Delivery.InstructorDashboard.ContentTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core

  defp live_view_content_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :content,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fcontent"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_content_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_content_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_content_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      # Content tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_content_route(section.slug)}"].border-b-2},
               "Content"
             )

      # Content tab content gets rendered
      assert has_element?(view, ~s{form[id=container-select-form]})
    end

    test "content table gets rendered considering the given url params given a section with units and modules",
         %{
           instructor: instructor,
           conn: conn
         } do
      %{
        section: section,
        mod1_pages: mod1_pages,
        unit1_resource: unit1_resource,
        unit2_resource: unit2_resource
      } = Oli.Seeder.base_project_with_larger_hierarchy()

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

      ### sorting by module
      params = %{
        sort_order: :desc,
        sort_by: :container_name,
        container_filter_by: :modules
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [module_for_tr_1, module_for_tr_2, module_for_tr_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert module_for_tr_1 =~ "Module 3"
      assert module_for_tr_2 =~ "Module 2"
      assert module_for_tr_3 =~ "Module 1"

      ### text filtering
      params = %{
        text_search: "Module 2",
        container_filter_by: :modules
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [module_for_tr_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert module_for_tr_1 =~ "Module 2"

      assert element(view, "#content_search_input-input") |> render() =~
               ~s'value="Module 2"'

      refute render(view) =~ "Module 1 "
      refute render(view) =~ "Module 3"

      ### pagination
      params = %{
        offset: 2,
        limit: 2,
        container_filter_by: :modules
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [module_for_tr_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert module_for_tr_1 =~ "Module 3"
      refute render(view) =~ "Module 1"
      refute render(view) =~ "Module 2"

      assert element(view, "#header_paging div:first-child") |> render() =~
               "Showing result 3 - 3 of 3 total"

      [top_selected_page, bottom_selected_page] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{li.page-item.active a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert top_selected_page == bottom_selected_page and bottom_selected_page =~ "2"

      ### filtering by modules
      params = %{container_filter_by: :modules}

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["15%", "0%", "0%"]

      ### filtering by units
      params = %{container_filter_by: :units}

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["8%", "0%"]

      ### links to students tab with container_id as url param
      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      links =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Floki.attribute("href")

      assert links == [
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{container_id: unit1_resource.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{container_id: unit2_resource.id}
               )
             ]

      ### both "units" and "modules" options are shown to user in dropdown
      options_for_select =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{#container_select option})
        |> Floki.attribute("value")

      assert options_for_select == ["modules", "units"]
    end

    test "content table given a section with only units",
         %{
           instructor: instructor,
           conn: conn
         } do
      %{
        unit1_resource: unit1_resource,
        unit2_resource: unit2_resource,
        section: section
      } = Oli.Seeder.base_project_with_units()

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      ### links to students tab with unit_id as url param
      links =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Floki.attribute("href")

      assert links == [
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{container_id: unit1_resource.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{container_id: unit2_resource.id}
               )
             ]

      ### only "units" option is shown to user in dropdown
      options_for_select =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{#container_select option})
        |> Floki.attribute("value")

      assert options_for_select == ["units"]
    end

    test "content table gets rendered given a section with only pages",
         %{
           instructor: instructor,
           conn: conn
         } do
      %{page1: page1, page2: page2, section: section} = Oli.Seeder.base_project_with_pages()

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

      set_progress(section.id, page1.id, user_1.id, 0.9)
      set_progress(section.id, page1.id, user_2.id, 0.6)
      set_progress(section.id, page1.id, user_3.id, 0)
      set_progress(section.id, page1.id, user_4.id, 0.3)

      set_progress(section.id, page2.id, user_1.id, 0.8)
      set_progress(section.id, page2.id, user_2.id, 0.8)
      set_progress(section.id, page2.id, user_3.id, 0.8)
      set_progress(section.id, page2.id, user_4.id, 0.8)

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) end)

      assert progress == ["45%", "80%"]

      ### links to students tab with page_id as url param
      links =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Floki.attribute("href")

      assert links == [
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{page_id: page1.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :students,
                 %{page_id: page2.id}
               )
             ]

      ### only "pages" option is shown to user in dropdown
      options_for_select =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{#container_select option})
        |> Floki.attribute("value")

      assert options_for_select == ["pages"]
    end
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end
end

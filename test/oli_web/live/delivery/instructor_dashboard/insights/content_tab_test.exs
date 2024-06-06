defmodule OliWeb.Delivery.InstructorDashboard.ContentTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core
  alias Oli.Seeder

  defp live_view_content_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :insights,
      :content,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Finsights%2Fcontent"

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
      assert has_element?(view, ~s{button[id=filter_units_button]})
      assert has_element?(view, ~s{button[id=filter_modules_button]})
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
      } = Seeder.base_project_with_larger_hierarchy()

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

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_1.id,
        0.9,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_2.id,
        0.6,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_3.id,
        0,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_4.id,
        0.3,
        page_1.revision
      )

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

      assert element(view, "#footer_paging > div:first-child") |> render() =~
               "3 - 3 of 3 results"

      selected_page =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{li.page-item.active button})
        |> Floki.text()

      assert selected_page =~ "2"

      ### filtering by modules
      params = %{container_filter_by: :modules}

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["15%", "0%", "0%"]

      ### filtering by units
      params = %{container_filter_by: :units}

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

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
                 :insights,
                 :content,
                 %{container_id: unit1_resource.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :insights,
                 :content,
                 %{container_id: unit2_resource.id}
               )
             ]

      ### both "units" and "modules" buttons are shown to user
      options_for_select =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{button[phx-click="filter_container"]})
        |> Floki.attribute("phx-value-filter")

      assert options_for_select == ["units", "modules"]
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
      } = Seeder.base_project_with_units()

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      ### links to content tab with unit_id as url param
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
                 :insights,
                 :content,
                 %{container_id: unit1_resource.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :insights,
                 :content,
                 %{container_id: unit2_resource.id}
               )
             ]

      ### "units" button is selected
      assert has_element?(view, "button.bg-blue-500", "Units")
      refute has_element?(view, "button.bg-white", "Units")
      assert has_element?(view, "button.bg-white", "Modules")
      refute has_element?(view, "button.bg-blue-500", "Modules")
    end

    test "content table gets rendered given a section with only pages",
         %{
           instructor: instructor,
           conn: conn
         } do
      %{
        page1: page1,
        revision1: revision1,
        page2: page2,
        revision2: revision2,
        page3: page3,
        revision3: revision3,
        section: section
      } =
        Oli.Seeder.base_project_with_pages()

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

      set_progress(section.id, page1.id, user_1.id, 0.9, revision1)
      set_progress(section.id, page1.id, user_2.id, 0.6, revision1)
      set_progress(section.id, page1.id, user_3.id, 0, revision1)
      set_progress(section.id, page1.id, user_4.id, 0.3, revision1)

      set_progress(section.id, page2.id, user_1.id, 0.8, revision2)
      set_progress(section.id, page2.id, user_2.id, 0.8, revision2)
      set_progress(section.id, page2.id, user_3.id, 0.8, revision2)
      set_progress(section.id, page2.id, user_4.id, 0.8, revision2)

      set_progress(section.id, page3.id, user_1.id, 0.9, revision3)
      set_progress(section.id, page3.id, user_2.id, 0.6, revision3)
      set_progress(section.id, page3.id, user_3.id, 0, revision3)
      set_progress(section.id, page3.id, user_4.id, 0.3, revision3)

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["45%", "80%", "45%"]

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
                 :insights,
                 :content,
                 %{page_id: page1.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :insights,
                 :content,
                 %{page_id: page2.id}
               ),
               Routes.live_path(
                 OliWeb.Endpoint,
                 OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
                 section.slug,
                 :insights,
                 :content,
                 %{page_id: page3.id}
               )
             ]
    end

    test "content tab shows the container details view when a student is clicked on the contents table",
         %{
           instructor: instructor,
           conn: conn
         } do
      %{
        section: section,
        mod1_pages: mod1_pages
      } = Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Diego", family_name: "Forlán"})
      user_2 = insert(:user, %{given_name: "Federico", family_name: "Valverde"})
      user_3 = insert(:user, %{given_name: "Rodrigo", family_name: "Bentancur"})
      user_4 = insert(:user, %{given_name: "Diego", family_name: "Lugano"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_1.id,
        0.9,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_2.id,
        0.6,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_3.id,
        0,
        page_1.revision
      )

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_4.id,
        0.3,
        page_1.revision
      )

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      view
      |> element(".instructor_dashboard_table tbody tr:first-of-type a")
      |> render_click()

      assert has_element?(view, "h4", "Unit 1")
      assert has_element?(view, "a", "Download student progress CSV")
      assert has_element?(view, "th", "STUDENT NAME")
      assert has_element?(view, "th", "LAST INTERACTED")
      assert has_element?(view, "th", "COURSE PROGRESS")
      assert has_element?(view, "th", "OVERALL COURSE PROFICIENCY")
      assert has_element?(view, "tbody tr td", "Forlán, Diego")
      assert has_element?(view, "tbody tr td", "Valverde, Federico")
      assert has_element?(view, "tbody tr td", "Bentancur, Rodrigo")
      assert has_element?(view, "tbody tr td", "Lugano, Diego")
    end

    test "buttons to select containers works as expected", %{
      conn: conn,
      instructor: instructor
    } do
      %{section: section} = Seeder.base_project_with_larger_hierarchy()
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      ## filtering by modules
      element(view, "#filter_modules_button") |> render_click()

      assert has_element?(view, "button.bg-blue-500", "Modules")

      [module_for_tr_1, module_for_tr_2, module_for_tr_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert module_for_tr_1 =~ "Module 1"
      assert module_for_tr_2 =~ "Module 2"
      assert module_for_tr_3 =~ "Module 3"

      ## filtering by units
      element(view, "#filter_units_button") |> render_click()

      assert has_element?(view, "button.bg-blue-500", "Units")

      [unit_for_tr_1, unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_1 =~ "Unit 1"
      assert unit_for_tr_2 =~ "Unit 2"
    end

    test "cards to filter works correctly", %{
      conn: conn,
      instructor: instructor
    } do
      %{
        section: section,
        mod1_pages: mod1_pages
      } = Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, page_3] = mod1_pages
      user_1 = insert(:user, %{given_name: "Diego", family_name: "Forlán"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_1.id,
        1,
        page_1.revision
      )

      set_progress(
        section.id,
        page_2.published_resource.resource_id,
        user_1.id,
        1,
        page_2.revision
      )

      set_progress(
        section.id,
        page_3.published_resource.resource_id,
        user_1.id,
        1,
        page_3.revision
      )

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      [unit_for_tr_1, unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_1 =~ "Unit 1"
      assert unit_for_tr_2 =~ "Unit 2"

      ## Filtering by zero student progress card
      element(view, "div[phx-value-selected=\"2\"]") |> render_click()

      refute has_element?(view, "table tr td div a", unit_for_tr_1)
      assert has_element?(view, "table tr td div a", unit_for_tr_2)

      ## Filtering by High Progress, Low Proficiency card
      element(view, "div[phx-value-selected=\"1\"]") |> render_click()
      refute has_element?(view, "table tr td div a", unit_for_tr_1)
      refute has_element?(view, "table tr td div a", unit_for_tr_2)
    end

    test "cards to filter works correctly combined with input search", %{
      conn: conn,
      instructor: instructor
    } do
      %{
        section: section,
        mod1_pages: mod1_pages
      } = Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, page_3] = mod1_pages
      user_1 = insert(:user, %{given_name: "Diego", family_name: "Forlán"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(
        section.id,
        page_1.published_resource.resource_id,
        user_1.id,
        1,
        page_1.revision
      )

      set_progress(
        section.id,
        page_2.published_resource.resource_id,
        user_1.id,
        1,
        page_2.revision
      )

      set_progress(
        section.id,
        page_3.published_resource.resource_id,
        user_1.id,
        1,
        page_3.revision
      )

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      [unit_for_tr_1, unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_1 =~ "Unit 1"
      assert unit_for_tr_2 =~ "Unit 2"

      ## Filtering by zero student progress card
      element(view, "div[phx-value-selected=\"2\"]") |> render_click()

      assert has_element?(view, "table tr td div a", unit_for_tr_2)
      refute has_element?(view, "table tr td div a", unit_for_tr_1)

      ## Search for "Unit" string
      view
      |> element("form[phx-change=\"search_container\"]")
      |> render_change(%{container_name: "Unit"})

      assert has_element?(view, "table tr td div a", unit_for_tr_2)
      refute has_element?(view, "table tr td div a", unit_for_tr_1)
    end
  end

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end
end

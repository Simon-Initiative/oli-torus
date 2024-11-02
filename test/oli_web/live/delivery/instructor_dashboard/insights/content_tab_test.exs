defmodule OliWeb.Delivery.InstructorDashboard.ContentTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core
  alias Oli.Seeder
  alias Oli.Resources.ResourceType

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

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find(~s{.instructor_dashboard_table tbody tr td a})
             |> Floki.text() =~ "Module 2"

      assert element(view, "#content_search_input-input") |> render() =~
               ~s'value="Module 2"'

      ### pagination
      params = %{
        offset: 2,
        limit: 2,
        container_filter_by: :modules
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      assert view
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.find(~s{.instructor_dashboard_table tbody tr td a})
             |> Floki.text() =~ "Module 3"

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

      filtered_links = Enum.map(links, &remove_navigation_data/1)

      expected_links = [
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

      assert filtered_links == expected_links

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

      filtered_links = Enum.map(links, &remove_navigation_data/1)

      expected_links = [
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

      assert filtered_links == expected_links

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
      %{page1: page1, revision1: revision1, page2: page2, revision2: revision2, section: section} =
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

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["45%", "80%"]

      ### links to students tab with page_id as url param
      links =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Floki.attribute("href")

      filtered_links = Enum.map(links, &remove_navigation_data/1)

      expected_links = [
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
        )
      ]

      assert filtered_links == expected_links
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
      element(view, "div[phx-value-selected=\"zero_student_progress\"]") |> render_click()

      refute has_element?(view, "table tr td div a", unit_for_tr_1)
      assert has_element?(view, "table tr td div a", unit_for_tr_2)

      ## Filtering by High Progress, Low Proficiency card
      element(view, "div[phx-value-selected=\"high_progress_low_proficiency\"]") |> render_click()
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
      element(view, "div[phx-value-selected=\"zero_student_progress\"]") |> render_click()

      assert has_element?(view, "table tr td div a", unit_for_tr_2)
      refute has_element?(view, "table tr td div a", unit_for_tr_1)

      ## Search for "Unit" string
      view
      |> element("form[phx-change=\"search_container\"]")
      |> render_change(%{container_name: "Unit"})

      assert has_element?(view, "table tr td div a", unit_for_tr_2)
      refute has_element?(view, "table tr td div a", unit_for_tr_1)
    end

    test "filter by progress works correctly", %{
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

      # Filter by progress percentage greater than or equal to 50
      params = %{
        progress_percentage: "50",
        progress_selector: "is_equal_to"
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [unit_for_tr_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_1 =~ "Unit 1"

      # Filter by progress percentage less than or equal to 49
      params = %{
        progress_percentage: "49",
        progress_selector: "is_less_than_or_equal"
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_2 =~ "Unit 2"
    end
  end

  describe "learning proficiency calculations" do
    setup [:instructor_conn, :create_project]

    test "", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj,
      unit_1: _unit_1,
      unit_2: _unit_2,
      module_1: _module_1,
      module_2: _module_2,
      conn: conn,
      instructor: instructor
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_3, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_4, true)

      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_3, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_4, false)

      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_2, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_3, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_4, false)

      set_snapshot(section, page_4.resource, page_4_obj.resource, student_1, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_2, true)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_3, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_4, false)

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, %{}))

      [unit_for_tr_1, unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_1 =~ "Unit 1"
      assert unit_for_tr_2 =~ "Unit 2"

      ## Set proficiency filter to Low
      params = %{
        selected_proficiency_ids: Jason.encode!([1])
      }

      {:ok, view, _html} = live(conn, live_view_content_route(section.slug, params))

      [unit_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert unit_for_tr_2 =~ "Unit 2"
    end
  end

  defp set_snapshot(section, resource, objective, user, result) do
    insert(:snapshot, %{
      section: section,
      resource: resource,
      user: user,
      correct: result,
      objective: objective,
      attempt_number: 1,
      part_attempt_number: 1
    })
  end

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## objectives
    objective_1_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 4"
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page 1"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2"
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4"
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 2"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [module_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 2"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_2_revision.resource,
      revision: objective_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_3_revision.resource,
      revision: objective_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_4_revision.resource,
      revision: objective_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_3_revision.resource,
      revision: page_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_4_revision.resource,
      revision: page_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_1_revision.resource,
      revision: module_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_2_revision.resource,
      revision: module_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    # create section...
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students to section

    [student_1, student_2] = insert_pair(:user)
    [student_3, student_4] = insert_pair(:user)

    Sections.enroll(student_1.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_2.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_3.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_4.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_1_objective: objective_1_revision,
      page_2_objective: objective_2_revision,
      page_3_objective: objective_3_revision,
      page_4_objective: objective_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4
    }
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

  def remove_navigation_data(url) do
    uri = URI.parse(url)
    query_params = URI.decode_query(uri.query)
    filtered_query_params = Map.drop(query_params, ["navigation_data"])
    new_query = URI.encode_query(filtered_query_params)
    URI.to_string(%{uri | query: new_query})
  end
end

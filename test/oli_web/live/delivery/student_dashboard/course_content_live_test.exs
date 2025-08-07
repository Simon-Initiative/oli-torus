defmodule OliWeb.Delivery.StudentDashboard.CourseContentLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Delivery.StudentDashboard.CourseContentLive
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Repo
  alias Oli.Delivery.Gating

  defp isolated_live_view_course_content(conn, section_slug, user_id, preview_mode \\ false) do
    live_isolated(conn, CourseContentLive,
      session: %{
        "section_slug" => section_slug,
        "current_user_id" => user_id,
        "preview_mode" => preview_mode,
        "scheduled_dates" =>
          Sections.get_resources_scheduled_dates_for_student(section_slug, user_id)
      }
    )
  end

  defp section_with_larger_hierarchy(%{user: user} = _conn) do
    %{section: section, mod1_pages: mod1_pages} = Oli.Seeder.base_project_with_larger_hierarchy()
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

    %{section: section, mod1_pages: mod1_pages}
  end

  describe "course renders the browser correctly" do
    setup [:user_conn, :section_with_larger_hierarchy]

    test "with left arrow disabled", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      assert has_element?(
               view,
               "button[phx-click='previous_node'].grayscale.pointer-events-none"
             )
    end

    test "with breadcrumbs initially set to Curriculum", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      assert breadcrumbs_length(view) == 1
      assert has_element?(view, "button[phx-click='breadcrumb-navigate']", "Curriculum")
    end

    test "navigates left and right", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      assert has_element?(view, "#course_browser_node_title", "Page 1: Page one")

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "#course_browser_node_title", "Page 2: Page two")

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "#course_browser_node_title", "Unit 1: Unit 1")

      view
      |> element("button[phx-click='next_node']")
      |> render_click()

      assert has_element?(view, "#course_browser_node_title", "Unit 2: Unit 2")

      view
      |> element("button[phx-click='next_node'].grayscale.pointer-events-none")
      |> has_element?()

      view
      |> element("button[phx-click='previous_node']")
      |> render_click()

      assert has_element?(view, "#course_browser_node_title", "Unit 1: Unit 1")
    end

    test "navigates to next level in hierarchy", %{conn: conn, user: user, section: section} do
      {:ok, section} =
        Sections.update_section(section, %{
          customizations: %{unit: "Volume", module: "Chapter", section: "Lesson"}
        })

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()

      assert has_element?(view, "#course_browser_node_title", "Volume 1: Unit 1")

      view
      |> drill_down_to_module_1()

      assert has_element?(view, "#course_browser_node_title", "Chapter 1: Module 1")
    end

    test "displays custom labels", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert has_element?(view, "#course_browser_node_title", "Module 1: Module 1")
      assert has_element?(view, "h4", "Page 1")
      assert has_element?(view, "h4", "Page 2")
      assert has_element?(view, "h4", "Page 3")
    end

    test "updates breadcrumbs when navigating to next level in hierarchy", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert breadcrumbs_length(view) == 2

      assert has_element?(
               view,
               ~s{button[phx-click="breadcrumb-navigate"][phx-value-target_level="0"][phx-value-target_position="2"]},
               "Curriculum"
             )

      assert has_element?(
               view,
               ~s{button[phx-click="breadcrumb-navigate"][phx-value-target_level="1"][phx-value-target_position="0"]},
               "Unit 1"
             )
    end

    test "breadcrumbs navigation works fine", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert breadcrumbs_length(view) == 2

      # go back to Unit 1 through breadcrumbs
      element(
        view,
        ~s{button[phx-click="breadcrumb-navigate"][phx-value-target_level="1"][phx-value-target_position="0"]},
        "Unit 1"
      )
      |> render_click()

      assert breadcrumbs_length(view) == 1

      assert has_element?(view, "#course_browser_node_title", "Unit 1: Unit 1")
    end

    test "progress for resource gets rendered correctly", %{
      conn: conn,
      user: user,
      section: section,
      mod1_pages: mod1_pages
    } do
      {:ok, _} = Sections.rebuild_contained_pages(section)

      [p1, p2, p3] = mod1_pages

      p1_progress = 0.75
      p2_progress = 1.0
      p3_progress = 0.50

      set_progress(section.id, p1.published_resource.resource_id, user.id, p1_progress)
      set_progress(section.id, p2.published_resource.resource_id, user.id, p2_progress)
      set_progress(section.id, p3.published_resource.resource_id, user.id, p3_progress)

      expected_progress = (p1_progress + p2_progress + p3_progress) / 3 * 100

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      ["width:", progress_value] =
        view
        |> element("#browser_overall_progress_bar div")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.attribute("style")
        |> hd()
        |> String.split(" ")

      assert "#{expected_progress}%" == progress_value
    end

    test "scheduled dates gets rendered correctly", %{
      conn: conn,
      user: user,
      section: section,
      mod1_pages: mod1_pages
    } do
      [p1, p2, _p3] = mod1_pages

      read_by_end_date = ~U[2023-10-15 12:00:00Z]
      inclass_end_date = ~U[2023-10-01 12:00:00Z]

      update_section_resource(section.id, p1.published_resource.resource_id, %{
        end_date: read_by_end_date,
        scheduling_type: :read_by
      })

      update_section_resource(section.id, p2.published_resource.resource_id, %{
        end_date: inclass_end_date,
        scheduling_type: :inclass_activity
      })

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "Read by #{FormatDateTime.date(read_by_end_date)}"
             )

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "In class on #{FormatDateTime.date(inclass_end_date)}"
             )

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "No due date"
             )
    end

    test "scheduled dates considers student exceptions", %{
      conn: conn,
      user: user,
      section: section,
      mod1_pages: mod1_pages
    } do
      [p1, p2, _p3] = mod1_pages

      read_by_end_date = ~U[2023-10-15 12:00:00Z]
      inclass_end_date = ~U[2023-10-01 12:00:00Z]

      update_section_resource(section.id, p1.published_resource.resource_id, %{
        end_date: read_by_end_date,
        scheduling_type: :read_by
      })

      update_section_resource(section.id, p2.published_resource.resource_id, %{
        end_date: inclass_end_date,
        scheduling_type: :inclass_activity
      })

      ## set a student exception
      student_exception_end_date = ~U[2023-10-29 12:00:00Z]

      Oli.Delivery.create_delivery_setting(%{
        resource_id: p2.published_resource.resource_id,
        section_id: section.id,
        user_id: user.id,
        end_date: student_exception_end_date
      })

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "Read by #{FormatDateTime.date(read_by_end_date)}"
             )

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "In class on #{FormatDateTime.date(student_exception_end_date)}"
             )

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "No due date"
             )
    end

    test "hard scheduled dates and student-specific hard scheduled dates are rendered correctly",
         %{
           conn: conn,
           user: user,
           section: section,
           mod1_pages: mod1_pages
         } do
      [p1, p2, _p3] = mod1_pages

      read_by_end_date = ~U[2023-10-15 12:00:00Z]
      inclass_end_date = ~U[2023-10-01 12:00:00Z]

      update_section_resource(section.id, p1.published_resource.resource_id, %{
        end_date: read_by_end_date,
        scheduling_type: :read_by
      })

      update_section_resource(section.id, p2.published_resource.resource_id, %{
        end_date: inclass_end_date,
        scheduling_type: :inclass_activity
      })

      # set hard scheduled dates for page 1 and page 2
      hard_scheduled_date_1 = ~U[2023-10-24 15:39:16.949268Z]
      hard_scheduled_date_2 = ~U[2023-10-25 15:39:16.949268Z]

      create_global_hard_scheduled_date(
        section.id,
        p1.published_resource.resource_id,
        hard_scheduled_date_1
      )

      create_global_hard_scheduled_date(
        section.id,
        p2.published_resource.resource_id,
        hard_scheduled_date_2
      )

      # set specific student hard end date for page 2
      hard_scheduled_date_for_student = ~U[2023-10-30 15:39:16.949268Z]

      create_hard_scheduled_date_for_student(
        section.id,
        p2.published_resource.resource_id,
        user.id,
        hard_scheduled_date_for_student
      )

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "Due by #{FormatDateTime.date(hard_scheduled_date_1)}"
             )

      assert has_element?(
               view,
               ~s{section:has(h4[phx-click="go_down"]) span},
               "No due date"
             )
    end

    test "can open a container resource", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      navigate_to_unit_1(view)

      # open module 1
      resource_slug = "module_1"

      view
      |> element(
        ~s{button[phx-click="open_resource"][phx-value-resource_slug="#{resource_slug}"]}
      )
      |> render_click()

      assert_redirected(
        view,
        Routes.page_delivery_path(
          OliWeb.Endpoint,
          :container,
          section.slug,
          resource_slug
        )
      )
    end

    test "can open a container resource in preview mode", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id, true)

      navigate_to_unit_1(view)

      # open module 1
      resource_slug = "module_1"

      view
      |> element(
        ~s{button[phx-click="open_resource"][phx-value-resource_slug="#{resource_slug}"]}
      )
      |> render_click()

      assert_redirected(
        view,
        Routes.page_delivery_path(
          OliWeb.Endpoint,
          :container_preview,
          section.slug,
          resource_slug
        )
      )
    end

    test "can open a page resource", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      # open page 2
      resource_slug = "page_2"

      view
      |> element(
        ~s{button[phx-click="open_resource"][phx-value-resource_slug="#{resource_slug}"]}
      )
      |> render_click()

      assert_redirected(
        view,
        Routes.page_delivery_path(
          OliWeb.Endpoint,
          :page,
          section.slug,
          resource_slug
        )
      )
    end

    test "can open a page resource in preview mode", %{conn: conn, user: user, section: section} do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id, true)

      view
      |> navigate_to_unit_1()
      |> drill_down_to_module_1()

      # open page 2
      resource_slug = "page_2"

      view
      |> element(
        ~s{button[phx-click="open_resource"][phx-value-resource_slug="#{resource_slug}"]}
      )
      |> render_click()

      assert_redirected(
        view,
        Routes.page_delivery_path(
          OliWeb.Endpoint,
          :page_preview,
          section.slug,
          resource_slug
        )
      )
    end

    test "units and modules correctly display and hide item numbering", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id, true)

      # Checks that the resource are rendered correctly with item numbering

      navigate_to_unit_1(view)
      assert has_element?(view, "#course_browser_node_title", "Unit 1: Unit 1")
      assert has_element?(view, "h4", "1.1 Module 1")
      assert has_element?(view, "h4", "1.2 Module 2")

      # Updates section to not display item numbering

      Sections.update_section(section, %{
        display_curriculum_item_numbering: false
      })

      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id, true)

      # Checks that the resource are rendered correctly without item numbering

      navigate_to_unit_1(view)
      assert has_element?(view, "#course_browser_node_title", "Unit: Unit 1")
      assert has_element?(view, "h4", "Module 1")
      assert has_element?(view, "h4", "Module 2")
    end

    test "does not show flash message after update timezone", %{
      conn: conn,
      user: user,
      section: section
    } do
      {:ok, view, _html} = isolated_live_view_course_content(conn, section.slug, user.id)
      redirect_to = ~p"/sections/#{section.slug}"
      new_timezone = "America/Montevideo"

      conn =
        post(conn, ~p"/update_timezone", %{
          timezone: %{
            timezone: new_timezone,
            redirect_to: redirect_to
          }
        })

      assert redirected_to(conn, 302) == redirect_to

      refute has_element?(
               view,
               "div.alert.alert-info[id=\"live_flash_container\"]",
               "Timezone updated successfully."
             )
    end
  end

  defp breadcrumbs_length(view) do
    view
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find(~s{button[phx-click="breadcrumb-navigate"]})
    |> length()
  end

  defp navigate_to_unit_1(view) do
    # navigate in right direction to unit 1 resource
    view
    |> element("button[phx-click='next_node']")
    |> render_click()

    view
    |> element("button[phx-click='next_node']")
    |> render_click()

    view
  end

  defp drill_down_to_module_1(view) do
    view
    |> element("h4[phx-click='go_down']", "1.1 Module 1")
    |> render_click()

    view
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end

  defp update_section_resource(section_id, resource_id, params) do
    query =
      from(sr in SectionResource,
        where: sr.section_id == ^section_id and sr.resource_id == ^resource_id
      )

    Repo.one(query)
    |> Oli.Delivery.Sections.SectionResource.changeset(params)
    |> Repo.update()
  end

  defp create_global_hard_scheduled_date(section_id, resource_id, end_date) do
    update_section_resource(section_id, resource_id, %{
      end_date: end_date,
      scheduling_type: :due_by
    })
  end

  defp create_hard_scheduled_date_for_student(section_id, resource_id, student_id, end_date) do
    Gating.create_gating_condition(%{
      type: :schedule,
      resource_id: resource_id,
      section_id: section_id,
      user_id: student_id,
      data: %{end_datetime: end_date}
    })
  end
end

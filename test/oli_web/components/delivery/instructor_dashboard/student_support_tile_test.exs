defmodule OliWeb.Components.Delivery.InstructorDashboard.StudentSupportTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias LiveComponentTests.Driver

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile

  describe "StudentSupportTile" do
    test "renders default bucket, counts, first 20 students, and load more", %{conn: conn} do
      {:ok, component, html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      assert has_element?(component, "h3", "Student Support")

      assert has_element?(
               component,
               "a[href='/sections/elixir_30/instructor_dashboard/overview/students']",
               "View Student Overview"
             )

      assert has_element?(component, "a[data-filter='active']", "Active (23)")
      assert has_element?(component, "a[data-filter='inactive']", "Inactive (2)")
      assert has_element?(component, "p", "Student 1")
      assert has_element?(component, "p", "Student 20")
      refute has_element?(component, "p", "Student 21")
      assert has_element?(component, "a[data-role='load-more']", "Load 5 more (5 remaining)")

      assert has_element?(
               component,
               "a[data-role='view-profile'][href='/sections/elixir_30/student_dashboard/1/content']"
             )

      assert has_element?(component, "button[disabled]", "Email Selected")
      assert html =~ "bg-Fill-Chip-Gray"
      assert html =~ "hover:bg-Surface-surface-secondary-hover"
      assert html =~ "group-hover:bg-Fill-Chart-fill-chart-blue-active"
      assert html =~ "group-hover:bg-Icon-icon-default"
      assert html =~ "border-Text-text-button"
      assert html =~ "border-Border-border-default"
      assert html =~ "bg-Fill-Chart-fill-chart-red-active"
      assert html =~ "group-hover:pointer-events-auto"
      assert html =~ "group-hover:opacity-100"
      assert html =~ "hover:bg-Table-table-hover"
      assert html =~ "focus-within:border-Border-border-hover"
      assert html =~ "bg-Fill-Buttons-fill-secondary-hover"
      assert html =~ "text-Text-text-button-hover"
      assert html =~ "View Profile"
      assert has_element?(
               component,
               "button[aria-label='Edit parameters'][title='Edit parameters']"
             )

      refute has_element?(component, "#student_support_parameters_modal_student_support_tile")
    end

    test "renders parameterized thresholds and inactive copy", %{conn: conn} do
      projection =
        projection()
        |> Map.put(:parameters, %{
          inactivity_days: 14,
          struggling_progress_low_lt: 35,
          struggling_progress_high_gt: 90,
          struggling_proficiency_lte: 30,
          excelling_progress_gte: 90,
          excelling_proficiency_gte: 75
        })

      {:ok, component, _html} =
        live_component_isolated(
          conn,
          StudentSupportTile,
          base_attrs(%{projection: projection, tile_state: tile_state()})
        )

      assert has_element?(component, "span", "< 35%")
      assert has_element?(component, "span", "> 90%")
      assert has_element?(component, "span", "≤ 30%")

      assert has_element?(
               component,
               "a[data-filter='inactive'][title='Inactive = no activity in the past 14 days']"
             )
    end

    test "renders customize parameters modal from LiveView-owned assigns", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(
          conn,
          StudentSupportTile,
          base_attrs(%{
            tile_state: tile_state(),
            show_student_support_parameters_modal: true,
            student_support_parameters_draft: %{
              inactivity_days: 30,
              struggling_progress_low_lt: 35,
              struggling_progress_high_gt: 90,
              struggling_proficiency_lte: 30,
              excelling_progress_gte: 90,
              excelling_proficiency_gte: 75
            }
          })
        )

      assert has_element?(component, "#student_support_parameters_modal_student_support_tile")
      assert render(component) =~ "Customize Student Support Parameters"
      assert render(component) =~ "StudentSupportParametersMatrix"
      assert render(component) =~ "value=\"30\""
      assert render(component) =~ "value=\"75\""
      assert render(component) =~ "data-student-points=\"true\""
      assert render(component) =~ "fill-[#FF9C54] opacity-[0.30]"
    end

    test "search term filters visible students but keeps bucket counts stable", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      rerender_component(
        component,
        base_attrs(%{tile_state: tile_state(%{search_term: "student 21"})})
      )

      assert has_element?(component, "a[data-filter='active']", "Active (23)")
      assert has_element?(component, "a[data-filter='inactive']", "Inactive (2)")
      assert has_element?(component, "p", "Student 21")
      refute has_element?(component, "p", "Student 1")
    end

    test "shows empty state when search has no matches", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      rerender_component(
        component,
        base_attrs(%{tile_state: tile_state(%{search_term: "nope", visible_count: 20})})
      )

      assert has_element?(component, "div", "No students match this filter.")
    end

    test "select all toggles only currently visible students", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      component
      |> element("button[aria-label='Select all visible students']")
      |> render_click()

      assert has_element?(
               component,
               "button[aria-label='Select Student 1'][aria-checked='true']"
             )

      assert has_element?(
               component,
               "button[aria-label='Select Student 20'][aria-checked='true']"
             )

      refute has_element?(
               component,
               "button[aria-label='Select Student 21'][aria-checked='true']"
             )

      assert has_element?(
               component,
               "button[aria-label='Select all visible students'][aria-checked='true']"
             )

      component
      |> element("button[aria-label='Select all visible students']")
      |> render_click()

      assert has_element?(
               component,
               "button[aria-label='Select Student 1'][aria-checked='false']"
             )

      assert has_element?(component, "button[disabled]", "Email Selected")
    end

    test "selection persists across load more but new rows stay unselected", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      component
      |> element("button[aria-label='Select all visible students']")
      |> render_click()

      rerender_component(
        component,
        base_attrs(%{tile_state: tile_state(%{visible_count: 25, page: 2})})
      )

      assert has_element?(component, "p", "Student 21")
      assert has_element?(component, "button[aria-label='Select Student 1'][aria-checked='true']")

      assert has_element?(
               component,
               "button[aria-label='Select Student 21'][aria-checked='false']"
             )

      assert has_element?(
               component,
               "button[aria-label='Select all visible students'][aria-checked='false']"
             )

      refute has_element?(component, "a[data-role='load-more']")
    end

    test "selection resets when the underlying bucket dataset changes", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      component
      |> element("button[aria-label='Select Student 1']")
      |> render_click()

      assert has_element?(component, "button[aria-label='Select Student 1'][aria-checked='true']")

      rerender_component(
        component,
        base_attrs(%{
          projection: projection_with_shifted_student_ids(),
          tile_state: tile_state()
        })
      )

      assert has_element?(
               component,
               "button[aria-label='Select Student 101'][aria-checked='false']"
             )

      assert has_element?(component, "button[disabled]", "Email Selected")
    end

    test "individual row toggle enables email button", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      component
      |> element("button[aria-label='Select Student 1']")
      |> render_click()

      assert has_element?(component, "button:not([disabled])", "Email Selected")
    end

    test "view profile action is scoped to the button link, not the whole row", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      refute has_element?(
               component,
               "div[href='/sections/elixir_30/student_dashboard/1/content']"
             )

      assert has_element?(
               component,
               "a[data-role='view-profile'][href='/sections/elixir_30/student_dashboard/1/content']",
               "View Profile"
             )
    end

    test "renders the student support email modal for the current selection", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, StudentSupportTile, base_attrs(%{tile_state: tile_state()}))

      component
      |> element("button[aria-label='Select Student 1']")
      |> render_click()

      rerender_component(
        component,
        base_attrs(%{tile_state: tile_state(), show_email_modal: true})
      )

      assert has_element?(component, "#student_support_email_modal_student_support_tile")
      assert render(component) =~ "student1@example.edu"
    end
  end

  defp rerender_component(component, attrs) do
    Driver.run(component, fn socket ->
      {:reply, :ok,
       Phoenix.Component.assign(socket,
         lc_module: StudentSupportTile,
         lc_attrs: Map.put_new(Map.new(attrs), :id, "student_support_tile")
       )}
    end)

    render(component)
  end

  defp base_attrs(overrides) do
    Map.merge(
      %{
        id: "student_support_tile",
        projection: projection(),
        tile_state: tile_state(),
        section_slug: "elixir_30",
        dashboard_scope: "course",
        params: %{},
        instructor_email: "instructor@example.edu",
        instructor_name: "Instructor Example",
        section_title: "Demo Section"
      },
      overrides
    )
  end

  defp tile_state(overrides \\ %{}) do
    Map.merge(
      %{
        selected_bucket_id: "struggling",
        selected_activity_filter: :all,
        search_term: "",
        page: 1,
        visible_count: 20
      },
      overrides
    )
  end

  defp projection do
    students =
      Enum.map(1..25, fn index ->
        %{
          id: index,
          display_name: "Student #{index}",
          searchable_text: String.downcase("Student #{index}"),
          picture: nil,
          email: "student#{index}@example.edu",
          activity_status: if(index <= 2, do: :inactive, else: :active),
          progress_pct: 25.0,
          proficiency_pct: 35.0
        }
      end)

    %{
      has_activity_data?: true,
      default_bucket_id: "struggling",
      totals: %{total_students: 25, active_students: 23, inactive_students: 2},
      buckets: [
        %{
          id: "struggling",
          label: "Struggling",
          count: 25,
          pct: 1.0,
          active_count: 23,
          inactive_count: 2,
          students: students
        },
        %{
          id: "excelling",
          label: "Excelling",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        },
        %{
          id: "on_track",
          label: "On Track",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        },
        %{
          id: "not_enough_information",
          label: "N/A",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        }
      ]
    }
  end

  defp projection_with_shifted_student_ids do
    students =
      Enum.map(101..125, fn index ->
        %{
          id: index,
          display_name: "Student #{index}",
          searchable_text: String.downcase("Student #{index}"),
          picture: nil,
          email: "student#{index}@example.edu",
          activity_status: if(index <= 102, do: :inactive, else: :active),
          progress_pct: 25.0,
          proficiency_pct: 35.0
        }
      end)

    %{
      has_activity_data?: true,
      default_bucket_id: "struggling",
      totals: %{total_students: 25, active_students: 23, inactive_students: 2},
      buckets: [
        %{
          id: "struggling",
          label: "Struggling",
          count: 25,
          pct: 1.0,
          active_count: 23,
          inactive_count: 2,
          students: students
        },
        %{
          id: "excelling",
          label: "Excelling",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        },
        %{
          id: "on_track",
          label: "On Track",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        },
        %{
          id: "not_enough_information",
          label: "N/A",
          count: 0,
          pct: 0.0,
          active_count: 0,
          inactive_count: 0,
          students: []
        }
      ]
    }
  end
end

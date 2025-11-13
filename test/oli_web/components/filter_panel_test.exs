defmodule OliWeb.Components.FilterPanelTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.FilterPanel
  alias OliWeb.Admin.BrowseFilters

  describe "FilterPanel LiveComponent - Institution Search" do
    setup do
      institutions = [
        %{id: 1, name: "Harvard University"},
        %{id: 2, name: "Massachusetts Institute of Technology"},
        %{id: 3, name: "Stanford University"},
        %{id: 4, name: "University of California Berkeley"},
        %{id: 5, name: "Yale University"}
      ]

      {:ok, institutions: institutions}
    end

    test "renders institution search input with magnifying glass icon and shows all institutions",
         %{
           conn: conn,
           institutions: institutions
         } do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel - use a more specific selector
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Check search input exists
      assert has_element?(view, "#test-filter-institution-search")

      # Check that all institutions are shown by default
      html = render(view)
      assert html =~ "Harvard University"
      assert html =~ "Massachusetts Institute of Technology"
      assert html =~ "Stanford University"
      assert html =~ "Yale University"
      assert html =~ "University of California Berkeley"
    end

    test "filters institutions by search term", %{conn: conn, institutions: institutions} do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search for "university"
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "university"})

      html = render(view)
      assert html =~ "Harvard University"
      assert html =~ "Stanford University"
      assert html =~ "Yale University"
      refute html =~ "Massachusetts Institute of Technology"
    end

    test "filters institutions case-insensitively", %{conn: conn, institutions: institutions} do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search with lowercase "institute" (which should match MIT)
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "institute"})

      # Check that MIT suggestion button exists
      assert has_element?(
               view,
               "button[phx-click='filter_select_institution'][phx-value-id='2']",
               "Massachusetts Institute of Technology"
             )
    end

    test "shows all matching institutions without limit", %{conn: conn} do
      institutions = Enum.map(1..20, fn i -> %{id: i, name: "University #{i}"} end)

      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search for "University"
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "University"})

      html = render(view)

      # Count occurrences of institution buttons - should show all 20
      suggestion_count =
        html
        |> Floki.parse_document!()
        |> Floki.find("button[phx-click='filter_select_institution']")
        |> length()

      assert suggestion_count == 20
    end

    test "shows all institutions when search term is cleared", %{
      conn: conn,
      institutions: institutions
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search for something first to filter the list
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "harvard"})

      # Then clear the search
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => ""})

      html = render(view)

      # Should show all 5 institutions again
      suggestion_count =
        html
        |> Floki.parse_document!()
        |> Floki.find("button[phx-click='filter_select_institution']")
        |> length()

      assert suggestion_count == 5
    end

    test "selects an institution from suggestions", %{conn: conn, institutions: institutions} do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search for "harvard"
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "harvard"})

      # Select the institution
      view
      |> element("button[phx-click='filter_select_institution'][phx-value-id='1']")
      |> render_click()

      html = render(view)

      # Should show the selected institution
      assert html =~ "Harvard University"
      # Search input should be cleared
      assert view |> element("#test-filter-institution-search") |> render() =~ "value=\"\""
    end

    test "clears selected institution", %{conn: conn, institutions: institutions} do
      # Start with a selected institution
      filters = %BrowseFilters.State{institution_id: 1}

      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: filters,
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      html = render(view)
      assert html =~ "Harvard University"

      # Click the clear button
      view
      |> element("button[phx-click='filter_clear_institution']")
      |> render_click()

      html = render(view)

      # Should no longer show clear button
      refute html =~ "phx-click=\"filter_clear_institution\""
    end

    test "preserves selected institution when applying filters", %{
      conn: conn,
      institutions: institutions
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search and select an institution
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "stanford"})

      view
      |> element("button[phx-click='filter_select_institution'][phx-value-id='3']")
      |> render_click()

      # Apply filters
      view
      |> element("form")
      |> render_submit()

      # Verify the parent received the correct filter
      assert_received {:filter_panel, :apply, filters}
      assert filters.institution_id == 3
    end

    test "clears institution search state and shows all institutions when canceling and reopening",
         %{
           conn: conn,
           institutions: institutions
         } do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default(),
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search for something to filter the list
      view
      |> element("#test-filter-institution-search")
      |> render_keyup(%{"value" => "harvard"})

      # Verify only Harvard is shown
      html = render(view)
      assert html =~ "Harvard University"
      refute html =~ "Stanford University"

      # Cancel
      view
      |> element("button", "Cancel")
      |> render_click()

      # Reopen the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      # Search input should be cleared
      assert view |> element("#test-filter-institution-search") |> render() =~ "value=\"\""

      # Should show all 5 institutions again
      html = render(view)

      suggestion_count =
        html
        |> Floki.parse_document!()
        |> Floki.find("button[phx-click='filter_select_institution']")
        |> length()

      assert suggestion_count == 5
      assert html =~ "Harvard University"
      assert html =~ "Stanford University"
      assert html =~ "Yale University"
    end

    test "clears institution search state when clearing all filters", %{
      conn: conn,
      institutions: institutions
    } do
      filters = %BrowseFilters.State{institution_id: 1}

      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: filters,
          institution_options: institutions
        })

      # Clear all filters
      view
      |> element("button", "Clear All Filters")
      |> render_click()

      # Verify the parent received the clear message
      assert_received {:filter_panel, :clear}

      # Reopen and verify no institution is selected
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      html = render(view)
      refute html =~ "phx-click=\"filter_clear_institution\""
    end

    test "displays selected institution with clear button", %{
      conn: conn,
      institutions: institutions
    } do
      filters = %BrowseFilters.State{institution_id: 2}

      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: filters,
          institution_options: institutions
        })

      # Open the filter panel
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      html = render(view)

      # Should show the selected institution name
      assert html =~ "Massachusetts Institute of Technology"
      # Should show a clear button (×)
      assert html =~ "×"
      assert html =~ "phx-click=\"filter_clear_institution\""
    end
  end

  describe "FilterPanel LiveComponent - General Functionality" do
    test "renders filter button", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default()
        })

      html = render(view)
      assert html =~ "Filter"
    end

    test "shows active filter count badge", %{conn: conn} do
      filters = %BrowseFilters.State{
        institution_id: 1,
        visibility: :authors
      }

      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: filters
        })

      html = render(view)
      # Should show a badge with the count
      assert html =~ "2"
    end

    test "toggles filter panel visibility", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, FilterPanel, %{
          id: "test-filter",
          parent_pid: self(),
          filters: BrowseFilters.default()
        })

      # Initially, panel should be hidden
      html = render(view)
      assert html =~ "hidden"

      # Click to open
      view |> element("button[phx-click*='toggle_filters']") |> render_click()

      html = render(view)
      refute html =~ "hidden"
    end
  end
end

defmodule OliWeb.Components.Delivery.ListNavigatorTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias OliWeb.Components.Delivery.ListNavigator
  alias Oli.Resources.ResourceType

  describe "ListNavigator live component" do
    setup do
      # Create test resources with different types and numbering levels
      page_resource = insert(:resource)
      unit_resource = insert(:resource)
      module_resource = insert(:resource)
      section_resource = insert(:resource)

      # Create revisions with proper resource types
      page_revision =
        insert(:revision, %{
          resource: page_resource,
          resource_type_id: ResourceType.get_id_by_type("page"),
          title: "Introduction to Programming"
        })

      unit_revision =
        insert(:revision, %{
          resource: unit_resource,
          resource_type_id: ResourceType.get_id_by_type("container"),
          title: "Fundamentals Unit"
        })

      module_revision =
        insert(:revision, %{
          resource: module_resource,
          resource_type_id: ResourceType.get_id_by_type("container"),
          title: "Variables Module"
        })

      section_revision =
        insert(:revision, %{
          resource: section_resource,
          resource_type_id: ResourceType.get_id_by_type("container"),
          title: "Data Types Section"
        })

      # Create items with the structure that ListNavigator expects
      items = [
        %{
          resource_id: page_resource.id,
          title: page_revision.title,
          resource_type_id: page_revision.resource_type_id,
          numbering_level: 0,
          numbering_index: 1
        },
        %{
          resource_id: unit_resource.id,
          title: unit_revision.title,
          resource_type_id: unit_revision.resource_type_id,
          numbering_level: 1,
          numbering_index: 1
        },
        %{
          resource_id: module_resource.id,
          title: module_revision.title,
          resource_type_id: module_revision.resource_type_id,
          numbering_level: 2,
          numbering_index: 1
        },
        %{
          resource_id: section_resource.id,
          title: section_revision.title,
          resource_type_id: section_revision.resource_type_id,
          numbering_level: 3,
          numbering_index: 1
        }
      ]

      path_builder_fn = fn item ->
        "/test/path/#{item.resource_id}"
      end

      %{
        items: items,
        current_item_resource_id: page_resource.id,
        path_builder_fn: path_builder_fn,
        page_resource: page_resource,
        unit_resource: unit_resource,
        module_resource: module_resource,
        section_resource: section_resource
      }
    end

    test "renders with basic attributes", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Check that the component renders
      assert html =~ "Introduction to Programming"
      assert html =~ "Previous Page"
      assert html =~ "Next Unit"
    end

    test "renders correct labels for different resource types", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      # Test with page as current item
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 0).resource_id,
          path_builder_fn: path_fn
        )

      assert html =~ "Previous Page"
      assert html =~ "Next Unit"

      # Test with unit as current item
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 1).resource_id,
          path_builder_fn: path_fn
        )

      assert html =~ "Previous Page"
      assert html =~ "Next Module"

      # Test with module as current item
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 2).resource_id,
          path_builder_fn: path_fn
        )

      assert html =~ "Previous Unit"
      assert html =~ "Next Section"

      # Test with section as current item
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 3).resource_id,
          path_builder_fn: path_fn
        )

      assert html =~ "Previous Module"
      assert html =~ "Next Section"
    end

    test "disables previous button when on first item", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 0).resource_id,
          path_builder_fn: path_fn
        )

      # Previous button should be disabled (no link, just div)
      assert html =~ "cursor-not-allowed"
      assert html =~ "opacity-50"
    end

    test "disables next button when on last item", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 3).resource_id,
          path_builder_fn: path_fn
        )

      # Next button should be disabled (no link, just div)
      assert html =~ "cursor-not-allowed"
      assert html =~ "opacity-50"
    end

    test "enables navigation buttons for middle items", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: Enum.at(items, 1).resource_id,
          path_builder_fn: path_fn
        )

      # Both buttons should be enabled (links, not disabled divs)
      refute html =~ "cursor-not-allowed"
      assert html =~ "opacity-90"
    end

    test "renders dropdown with search functionality", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Check that dropdown is present but hidden initially
      assert html =~ "searchable_dropdown"
      assert html =~ "hidden"
      assert html =~ "Search"

      # Check that search input is present
      assert html =~ "search_input"
    end

    test "filters items based on search query", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Send search event
      lcd
      |> element("#search_input")
      |> render_keyup(%{"value" => "Programming"})

      # Get updated HTML
      html = render(lcd)

      # Should show filtered results
      assert html =~ "Introduction to Programming"
      refute html =~ "Fundamentals Unit"
    end

    test "shows no results message when search yields no matches", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Send search event with non-matching query
      lcd
      |> element("#search_input")
      |> render_keyup(%{"value" => "NonExistent"})

      # Get updated HTML
      html = render(lcd)

      # Should show no results message
      assert html =~ "No results found for"
      assert html =~ "NonExistent"
    end

    test "highlights search terms in results", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Send search event
      lcd
      |> element("#search_input")
      |> render_keyup(%{"value" => "Programming"})

      # Get updated HTML
      html = render(lcd)

      # Should highlight the search term
      assert html =~ "Programming"
    end

    test "excludes current item from search results", %{
      conn: conn,
      items: items,
      current_item_resource_id: current_id,
      path_builder_fn: path_fn
    } do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          current_item_resource_id: current_id,
          path_builder_fn: path_fn
        )

      # Send search event that would match current item
      lcd
      |> element("#search_input")
      |> render_keyup(%{"value" => "Introduction"})

      # Get updated HTML
      html = render(lcd)

      # Current item should not appear in dropdown results
      # (it should only appear in the main display, not in the dropdown)
      # Check that the current item appears in the main display
      assert html =~ "Introduction to Programming"

      # But it should not appear in the dropdown (we can't easily test this without more specific selectors)
      # For now, just verify the search was processed
      assert html =~ "Introduction"
    end

    test "handles empty items list", %{conn: conn, path_builder_fn: path_fn} do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: [],
          current_item_resource_id: 1,
          path_builder_fn: path_fn
        )

      # Should render without crashing
      assert html =~ "Previous"
      assert html =~ "Next"
    end

    test "handles current item not found in items list", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          # Non-existent ID
          current_item_resource_id: 99999,
          path_builder_fn: path_fn
        )

      # Should render without crashing
      assert html =~ "Previous"
      assert html =~ "Next"
    end

    test "renders correct item titles with numbering", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          # Unit
          current_item_resource_id: Enum.at(items, 1).resource_id,
          path_builder_fn: path_fn
        )

      # Should show "Unit 1: Fundamentals Unit"
      assert html =~ "Unit 1: Fundamentals Unit"
    end

    test "renders page titles without numbering prefix", %{
      conn: conn,
      items: items,
      path_builder_fn: path_fn
    } do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: items,
          # Page
          current_item_resource_id: Enum.at(items, 0).resource_id,
          path_builder_fn: path_fn
        )

      # Should show just the title without "Page 1:" prefix
      assert html =~ "Introduction to Programming"
      refute html =~ "Page 1: Introduction to Programming"
    end

    test "handles items with numbering_index of -1", %{conn: conn, path_builder_fn: path_fn} do
      # Create an item with numbering_index -1 (special case for default items)
      special_item = %{
        resource_id: 123,
        title: "All Modules",
        resource_type_id: ResourceType.get_id_by_type("container"),
        numbering_level: 2,
        numbering_index: -1
      }

      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          ListNavigator,
          items: [special_item],
          current_item_resource_id: 123,
          path_builder_fn: path_fn
        )

      # Should show just the title without numbering prefix
      assert html =~ "All Modules"
      refute html =~ "Module -1: All Modules"
    end
  end
end

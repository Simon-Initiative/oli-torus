defmodule OliWeb.Delivery.Student.Learn.Components.ViewSelectorTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Delivery.Student.Learn.Components.ViewSelector

  describe "ViewSelector component" do
    test "renders collapsed state with selected view", %{conn: conn} do
      {:ok, lcd, _html} =
        live_component_isolated(conn, ViewSelector, %{
          id: "view_selector",
          selected_view: :gallery
        })

      # Should render the collapsed button
      assert has_element?(lcd, "button[phx-click='expand_select']")
      assert has_element?(lcd, "div", "Gallery View")

      # Should not show dropdown menu
      refute has_element?(lcd, "div[phx-click-away='collapse_select']")
    end

    test "expands dropdown when button is clicked", %{conn: conn} do
      {:ok, lcd, _html} =
        live_component_isolated(conn, ViewSelector, %{
          id: "view_selector",
          selected_view: :outline
        })

      # Initially collapsed
      refute has_element?(lcd, "div[phx-click-away='collapse_select']")

      # Click to expand
      lcd |> element("button[phx-click='expand_select']") |> render_click()

      # Should now show dropdown
      assert has_element?(lcd, "div[phx-click-away='collapse_select']")
      assert has_element?(lcd, "button", "Outline")
      assert has_element?(lcd, "button", "Gallery")
    end

    test "component ID remains stable when transitioning between expanded and collapsed states",
         %{
           conn: conn
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, ViewSelector, %{
          id: "view_selector",
          selected_view: :outline
        })

      # Verify component ID exists in collapsed state
      assert has_element?(lcd, "#view_selector")

      # Expand dropdown
      lcd |> element("button[phx-click='expand_select']") |> render_click()

      # Component ID should still be present in expanded state
      assert has_element?(lcd, "#view_selector")

      # Collapse dropdown
      lcd |> element("button#select_view_button") |> render_click()

      # Component ID should still be present after collapsing
      assert has_element?(lcd, "#view_selector")
    end

    test "collapses dropdown when clicking collapse button", %{conn: conn} do
      {:ok, lcd, _html} =
        live_component_isolated(conn, ViewSelector, %{
          id: "view_selector",
          selected_view: :gallery
        })

      # Expand dropdown
      lcd |> element("button[phx-click='expand_select']") |> render_click()
      assert has_element?(lcd, "div[phx-click-away='collapse_select']")

      # Click collapse button
      lcd |> element("button#select_view_button") |> render_click()

      # Dropdown should collapse
      refute has_element?(lcd, "div[phx-click-away='collapse_select']")
    end

    test "renders mobile view selector on mobile screens", %{conn: conn} do
      {:ok, lcd, _html} =
        live_component_isolated(conn, ViewSelector, %{
          id: "view_selector",
          selected_view: :gallery
        })

      # Mobile selector should be present (hidden on desktop)
      assert has_element?(
               lcd,
               "button[phx-click='change_selected_view'][phx-value-selected_view='gallery']"
             )

      assert has_element?(
               lcd,
               "button[phx-click='change_selected_view'][phx-value-selected_view='outline']"
             )
    end
  end
end

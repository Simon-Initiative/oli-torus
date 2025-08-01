defmodule OliWeb.Components.Delivery.ExplorationListTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ExplorationList

  describe "render/1" do
    test "renders exploration list with explorations" do
      explorations = [
        %{id: 1, title: "Exploration 1", slug: "exploration-1"},
        %{id: 2, title: "Exploration 2", slug: "exploration-2"}
      ]

      assigns = %{
        explorations: explorations,
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&ExplorationList.render/1, assigns)

      assert html =~ "Exploration 1"
      assert html =~ "Exploration 2"
      refute html =~ "There are no exploration pages available"
    end

    test "renders empty state when no explorations" do
      assigns = %{
        explorations: [],
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&ExplorationList.render/1, assigns)

      assert html =~ "There are no exploration pages available"
      refute html =~ "Exploration"
    end

    test "renders with correct styling classes" do
      explorations = [
        %{id: 1, title: "Exploration 1", slug: "exploration-1"}
      ]

      assigns = %{
        explorations: explorations,
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&ExplorationList.render/1, assigns)

      # Check for expected CSS classes
      assert html =~ "flex flex-col"
      assert html =~ "gap-4"
    end

    test "renders empty state with correct styling" do
      assigns = %{
        explorations: [],
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&ExplorationList.render/1, assigns)

      # Check empty state styling
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "border-l-4"
      assert html =~ "border-delivery-primary"
      assert html =~ "p-4"
      assert html =~ "role=\"alert\""
    end

    test "passes correct props to ExplorationCard components" do
      explorations = [
        %{id: 1, title: "Exploration 1", slug: "exploration-1"}
      ]

      assigns = %{
        explorations: explorations,
        section_slug: "test-section",
        preview_mode: true
      }

      html = render_component(&ExplorationList.render/1, assigns)

      # Should render ExplorationCard components with correct props
      assert html =~ "Exploration 1"
      assert html =~ "test-section"
    end
  end
end

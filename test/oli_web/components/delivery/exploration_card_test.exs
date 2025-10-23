defmodule OliWeb.Components.Delivery.ExplorationCardTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ExplorationCard

  describe "render/1" do
    test "renders exploration card with basic information" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      assert html =~ "Test Exploration"
      assert html =~ "Open"
      assert html =~ "bg-white"
      refute html =~ "bg-delivery-instructor-dashboard-header-800"
    end

    test "renders exploration card in dark mode" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: true
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      assert html =~ "Test Exploration"
      assert html =~ "Open"
      assert html =~ "bg-delivery-instructor-dashboard-header-800"
      assert html =~ "text-white"
    end

    test "generates correct preview mode URL" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: true,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      assert html =~ "/sections/test-section/preview/page/test-exploration"
    end

    test "generates correct delivery mode URL" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      assert html =~ "/sections/test-section/page/test-exploration"
    end

    test "renders with correct styling classes" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      # Check for expected CSS classes
      assert html =~ "@container/card"
      assert html =~ "flex-1"
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "dark:text-white"
      assert html =~ "shadow"
      assert html =~ "p-6"
      assert html =~ "flex flex-col"
      assert html =~ "font-semibold"
      assert html =~ "text-lg"
      assert html =~ "leading-6"
    end

    test "renders with responsive design classes" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      # Check for responsive design classes
      assert html =~ "@2xl/card:flex-row"
      assert html =~ "@2xl/card:items-center"
      assert html =~ "@2xl/card:justify-between"
    end

    test "renders button with correct styling" do
      exploration = %{
        title: "Test Exploration",
        slug: "test-exploration"
      }

      assigns = %{
        exploration: exploration,
        section_slug: "test-section",
        preview_mode: false,
        dark: false
      }

      html = render_component(&ExplorationCard.render/1, assigns)

      # Check button styling
      assert html =~ "btn"
      assert html =~ "text-white"
      assert html =~ "hover:text-white"
      assert html =~ "inline-flex"
      assert html =~ "bg-delivery-primary"
      assert html =~ "hover:bg-delivery-primary-600"
      assert html =~ "active:bg-delivery-primary-700"
    end
  end
end

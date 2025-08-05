defmodule OliWeb.Components.Delivery.DiscussionPanelTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.DiscussionPanel

  describe "discussion_panel/1" do
    test "renders discussion panel with title" do
      assigns = %{}

      html = render_component(&DiscussionPanel.discussion_panel/1, assigns)

      assert html =~ "Discussion Activity"
      assert html =~ "No new discussion posts"
      assert html =~ "Post New Discussion"
    end

    test "renders with correct styling classes" do
      assigns = %{}

      html = render_component(&DiscussionPanel.discussion_panel/1, assigns)

      # Check for expected CSS classes
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "shadow"
      assert html =~ "p-4"
      assert html =~ "p-10"
      assert html =~ "text-center"
      assert html =~ "border-t"
      assert html =~ "border-gray-100"
      assert html =~ "dark:border-gray-700"
    end

    test "renders button with correct styling" do
      assigns = %{}

      html = render_component(&DiscussionPanel.discussion_panel/1, assigns)

      # Check button styling
      assert html =~ "px-6"
      assert html =~ "py-2.5"
      assert html =~ "text-delivery-primary"
      assert html =~ "hover:text-delivery-primary-600"
      assert html =~ "hover:underline"
      assert html =~ "active:text-delivery-primary-700"
      assert html =~ "fa-solid fa-plus"
    end

    test "renders with dark mode support" do
      assigns = %{}

      html = render_component(&DiscussionPanel.discussion_panel/1, assigns)

      # Check dark mode classes
      assert html =~ "dark:bg-gray-800"
      assert html =~ "dark:border-gray-700"
    end

    test "renders empty state message" do
      assigns = %{}

      html = render_component(&DiscussionPanel.discussion_panel/1, assigns)

      # Check for empty state styling
      assert html =~ "text-gray-500"
      assert html =~ "mb-2"
    end
  end
end

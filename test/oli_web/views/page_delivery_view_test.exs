defmodule OliWeb.PageDeliveryViewTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.PageDeliveryView

  describe "previous/next navigation links" do
    test "renders shrinkable text containers so long titles can truncate" do
      prev_html =
        render_component(&PageDeliveryView.prev_link/1, %{
          to: "/previous",
          title:
            "A very long page title that should truncate instead of pushing the arrow off screen"
        })

      next_html =
        render_component(&PageDeliveryView.next_link/1, %{
          to: "/next",
          title:
            "Another very long page title that should truncate instead of pushing the arrow off screen"
        })

      assert prev_html =~ ~s(class="flex flex-col text-right overflow-hidden flex-1 min-w-0")
      assert next_html =~ ~s(class="flex flex-col text-left overflow-hidden flex-1 min-w-0")
    end
  end
end

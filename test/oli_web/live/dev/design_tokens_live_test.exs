defmodule OliWeb.Dev.DesignTokensLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "design tokens catalog" do
    test "autodiscovers the Badge primitive alongside Button, with a correct copy snippet", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, ~p"/dev/design_tokens")

      assert html =~ "Design Tokens"
      assert has_element?(view, "button", "Primitives")

      rendered = render(view)

      # Both primitives are discovered and shown.
      assert rendered =~ "Badge"
      assert rendered =~ "Button"

      # The Badge preview actually renders its variants, not a placeholder.
      assert rendered =~ "My Section"
      assert rendered =~ "Template"

      # The copy-paste snippet for a Badge example must reference the Badge
      # component, never the Button-specific snippet format. HEEx auto-escapes
      # the `<`/`>` inside the rendered <pre><code> and data-copy-text attribute.
      assert rendered =~ "&lt;Badge.badge"
      refute rendered =~ "&lt;Button.button variant={:my_section}"

      # Badge has no meaningful "disabled" state, so it must not show one.
      refute has_element?(view, "[id^='copy-disabled-badge']")
    end
  end
end

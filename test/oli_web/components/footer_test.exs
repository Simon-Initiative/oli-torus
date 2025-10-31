defmodule OliWeb.Components.FooterTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Footer

  describe "delivery_footer/1" do
    test "renders license block when license is present (cc_by)" do
      html =
        render_component(&Footer.delivery_footer/1, %{
          license: %{license_type: :cc_by}
        })

      assert html =~ ~s(id="license")
    end

    test "does not render license block when license is nil" do
      html = render_component(&Footer.delivery_footer/1, %{})
      refute html =~ ~s(id="license")
    end
  end
end

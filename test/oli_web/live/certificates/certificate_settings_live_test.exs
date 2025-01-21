defmodule OliWeb.Certificates.CertificateSettingsLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "certificate settings live" do
    setup do
      product =
        insert(
          :section,
          %{title: "Test Product", certificate_enabled: false, type: :blueprint}
        )

      {:ok, %{product: product}}
    end

    test "renders the CertificateSettingsComponent", %{conn: conn, product: product} do
      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      {:ok, view, _html} =
        live(conn, ~p"/authoring/products/#{product.slug}/certificate_settings")

      assert has_element?(view, "div[data-phx-component]")
    end
  end
end

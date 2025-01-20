defmodule OliWeb.Certificates.CertificateSettingsComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory
  import LiveComponentTests

  alias Oli.Delivery.Sections
  alias OliWeb.Certificates.CertificateSettingsComponent

  describe "certificate settings component" do
    setup do
      product =
        insert(
          :section,
          %{title: "Test Product", certificate_enabled: false, type: :blueprint}
        )

      {:ok, product: product}
    end

    test "renders component correctly", %{conn: conn, product: product} do
      {:ok, lcd, _html} =
        live_component_isolated(conn, CertificateSettingsComponent, %{
          id: "certificate_settings_component",
          product: product
        })

      assert has_element?(lcd, "div[role=title]", "Certificate Settings")
      assert has_element?(lcd, "form", "Enable certificate capabilities for this product")

      # checkbox unchecked by default
      refute has_element?(lcd, "#enable_certificates_checkbox:checked")
    end

    test "toggles certificate_enabled", %{conn: conn, product: product} do
      # Mock para `Sections.update_section/2`
      {:ok, lcd, _html} =
        live_component_isolated(conn, CertificateSettingsComponent, %{
          id: "certificate_settings_component",
          product: product
        })

      # checkbox unchecked by default
      refute has_element?(lcd, "#enable_certificates_checkbox:checked")

      ## enable certificate
      lcd
      |> element("form[phx-change=\"toggle_certificate\"")
      |> render_change(%{"certificate_enabled" => "on"})

      # checkbox is checked
      assert has_element?(lcd, "#enable_certificates_checkbox:checked")

      assert Sections.get_section!(product.id).certificate_enabled

      ## disable certificate
      lcd
      |> element("form[phx-change=\"toggle_certificate\"")
      |> render_change()

      # checkbox is checked
      refute has_element?(lcd, "#enable_certificates_checkbox:checked")

      refute Sections.get_section!(product.id).certificate_enabled
    end
  end
end

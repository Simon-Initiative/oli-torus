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

      certificate = insert(:certificate, %{section: product})

      # graded pages
      graded_page_1_resource = insert(:resource)
      graded_page_2_resource = insert(:resource)

      graded_page_1_revision =
        insert(
          :revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Graded page 1",
          graded: true,
          resource: graded_page_1_resource
        )

      graded_page_2_revision =
        insert(
          :revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Graded page 2",
          graded: true,
          purpose: :application,
          resource: graded_page_2_resource
        )

      {:ok,
       product: product,
       certificate: certificate,
       graded_pages: [graded_page_1_revision, graded_page_2_revision]}
    end

    test "renders component correctly", %{
      conn: conn,
      product: product,
      certificate: certificate,
      graded_pages: graded_pages
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, CertificateSettingsComponent, %{
          id: "certificate_settings_component",
          product: product,
          certificate: certificate,
          graded_pages: graded_pages,
          active_tab: :thresholds,
          current_path: "/path"
        })

      assert has_element?(lcd, "div[role=title]", "Certificate Settings")
      assert has_element?(lcd, "form", "Enable certificate capabilities for this product")

      # checkbox unchecked by default
      refute has_element?(lcd, "#enable_certificates_checkbox:checked")
    end

    test "toggles certificate_enabled", %{
      conn: conn,
      product: product,
      certificate: certificate,
      graded_pages: graded_pages
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, CertificateSettingsComponent, %{
          id: "certificate_settings_component",
          product: product,
          certificate: certificate,
          graded_pages: graded_pages,
          active_tab: :thresholds,
          current_path: "/path"
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

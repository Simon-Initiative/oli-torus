defmodule OliWeb.Certificates.CertificateSettingsComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory
  import LiveComponentTests

  alias Oli.Delivery.Sections
  alias OliWeb.Certificates.CertificateSettingsComponent
  alias Oli.Delivery.Certificates

  describe "certificate settings component" do
    setup [:setup_data]

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

  describe "threshold tab" do
    setup [:setup_data]

    test "updates thresholds with correct values", %{
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

      assert has_element?(
               lcd,
               "div",
               "Customize the conditions students must meet to receive a certificate."
             )

      assert has_element?(lcd, "div", "Completion & Scoring")

      lcd
      |> element("#certificate_form")
      |> render_submit(%{
        "certificate" => %{
          "min_percentage_for_completion" => "80",
          "min_percentage_for_distinction" => "90",
          "required_discussion_posts" => "1",
          "required_class_notes" => "2",
          "section_id" => "#{product.id}",
          "requires_instructor_approval" => "true",
          "assessments_apply_to" => "all"
        }
      })

      updated_certificate = Certificates.get_certificate(certificate.id)

      assert updated_certificate.min_percentage_for_completion == 80
      assert updated_certificate.min_percentage_for_distinction == 90
      assert updated_certificate.required_discussion_posts == 1
      assert updated_certificate.required_class_notes == 2
      assert updated_certificate.requires_instructor_approval
      assert updated_certificate.assessments_apply_to == :all
      assert updated_certificate.section_id == product.id
    end

    test "fails when updating thresholds with incorrect values", %{
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

      lcd
      |> element("#certificate_form")
      |> render_submit(%{
        "certificate" => %{
          "min_percentage_for_completion" => "99",
          "min_percentage_for_distinction" => "90"
        }
      })

      assert has_element?(
               lcd,
               "div",
               "Min percentage for distinction must be greater than Min percentage for completion"
             )

      certificate = Certificates.get_certificate(certificate.id)

      refute certificate.min_percentage_for_completion == 99
      refute certificate.min_percentage_for_distinction == 90
    end

    test "toggles selection of scored pages", %{
      conn: conn,
      product: product,
      certificate: certificate,
      graded_pages: [gp1, gp2] = graded_pages
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

      ## toggles graded page 1
      lcd
      |> element("#multiselect_form")
      |> render_change(%{"resource_id" => "#{gp1.resource_id}"})

      # checkbox is checked
      assert has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")

      ## select all graded pages
      lcd
      |> element("button[phx-click=\"select_all_pages\"]")
      |> render_click()

      # all checkboxes are checked
      assert has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")
      assert has_element?(lcd, "input[name=\"#{gp2.resource_id}\"]:checked")

      ## deselect all graded pages
      lcd
      |> element("button[phx-click=\"deselect_all_pages\"]")
      |> render_click()

      # all checkboxes are unchecked
      refute has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")
      refute has_element?(lcd, "input[name=\"#{gp2.resource_id}\"]:checked")
    end
  end

  defp setup_data(%{}) do
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
end

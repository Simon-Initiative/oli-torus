defmodule OliWeb.Certificates.Components.ThresholdsTabTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.Sections.Certificate
  alias OliWeb.Certificates.Components.ThresholdsTab

  describe "thresholds component with write mode" do
    setup [:setup_data]

    test "updates thresholds with correct values", ctx do
      id = "thresholds_component"
      product = ctx.product
      certificate = ctx.certificate
      active_tab = :thresholds
      graded_pages = []

      attrs = %{
        id: id,
        section: product,
        certificate: certificate,
        active_tab: active_tab,
        graded_pages: graded_pages,
        read_only: false
      }

      {:ok, lcd, _html} = live_component_isolated(ctx.conn, ThresholdsTab, attrs)

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

    test "fails when updating thresholds with incorrect values", ctx do
      id = "thresholds_component"
      product = ctx.product
      certificate = ctx.certificate
      active_tab = :thresholds
      graded_pages = []

      attrs = %{
        id: id,
        section: product,
        certificate: certificate,
        active_tab: active_tab,
        graded_pages: graded_pages,
        read_only: false
      }

      {:ok, lcd, _html} = live_component_isolated(ctx.conn, ThresholdsTab, attrs)

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

      assert certificate.min_percentage_for_completion == 50.0
      assert certificate.min_percentage_for_distinction == 80.0
    end

    test "fails when selecting no graded pages", ctx do
      id = "thresholds_component"
      product = ctx.product
      certificate = ctx.certificate
      active_tab = :thresholds
      graded_pages = ctx.graded_pages

      attrs = %{
        id: id,
        section: product,
        certificate: certificate,
        active_tab: active_tab,
        graded_pages: graded_pages,
        read_only: false
      }

      {:ok, lcd, _html} = live_component_isolated(ctx.conn, ThresholdsTab, attrs)

      lcd
      |> element("#certificate_form")
      |> render_submit(%{
        "certificate" => %{
          "custom_assessments" => [],
          "assessments_apply_to" => "custom"
        }
      })

      assert has_element?(
               lcd,
               "div",
               "scored pages must not be empty"
             )

      certificate = Certificates.get_certificate(certificate.id)

      refute certificate.custom_assessments == [] and certificate.assessments_apply_to == :custom
    end

    test "toggles selection of scored pages", ctx do
      id = "thresholds_component"
      product = ctx.product
      certificate = ctx.certificate
      active_tab = :thresholds
      graded_pages = ctx.graded_pages

      attrs = %{
        id: id,
        section: product,
        certificate: certificate,
        active_tab: active_tab,
        graded_pages: graded_pages,
        read_only: false
      }

      {:ok, lcd, _html} = live_component_isolated(ctx.conn, ThresholdsTab, attrs)

      [gp1, gp2] = graded_pages

      ## toggles graded page 1
      lcd
      |> element("#multiselect_form")
      |> render_change(%{"resource_id" => "#{gp1.resource_id}"})

      # checkbox is checked
      assert has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")

      ## select all graded pages
      lcd
      |> element("button[phx-click='select_all_pages']")
      |> render_click()

      # all checkboxes are checked
      assert has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")
      assert has_element?(lcd, "input[name=\"#{gp2.resource_id}\"]:checked")

      ## deselect all graded pages
      lcd
      |> element("button[phx-click='deselect_all_pages']")
      |> render_click()

      # all checkboxes are unchecked
      refute has_element?(lcd, "input[name=\"#{gp1.resource_id}\"]:checked")
      refute has_element?(lcd, "input[name=\"#{gp2.resource_id}\"]:checked")
    end
  end

  describe "thresholds component with read only mode" do
    setup [:setup_data]

    test "can see threshold values but can not edit them", ctx do
      id = "thresholds_component"
      product = ctx.product
      active_tab = :thresholds
      [gp1, _] = graded_pages = ctx.graded_pages

      certificate =
        ctx.certificate
        |> Certificate.changeset(%{
          assessments_apply_to: :custom,
          custom_assessments: [gp1.resource_id]
        })
        |> Oli.Repo.update!()

      attrs = %{
        id: id,
        section: product,
        certificate: certificate,
        active_tab: active_tab,
        graded_pages: graded_pages,
        read_only: true
      }

      {:ok, lcd, _html} = live_component_isolated(ctx.conn, ThresholdsTab, attrs)

      # There is a lock icon
      assert has_element?(lcd, "svg[role=\"lock icon\"]")

      # There is a disabled fieldset
      assert has_element?(lcd, "fieldset[disabled]")

      # The cross icon button on the multiselect dropdown is disabled
      assert has_element?(lcd, "button[aria-label=\"Remove\"].cursor-not-allowed")
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

defmodule OliWeb.Certificates.Components.DesignTabTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias OliWeb.Certificates.Components.DesignTab

  describe "certificate design component" do
    setup [:setup_certificate]

    test "renders design component correctly", %{conn: conn, certificate: certificate} do
      {:ok, comp, _html} =
        live_component_isolated(conn, DesignTab, %{
          id: "certificate_design_component",
          certificate: certificate,
          read_only: false
        })

      # Check for static text and key form elements
      assert has_element?(comp, "div", "Create and preview your certificate.")
      assert has_element?(comp, "form#certificate-settings-design-form")
      assert has_element?(comp, ".text-base.font-bold", "Course Title")
      assert has_element?(comp, ".text-base.font-bold", "Subtitle")
      assert has_element?(comp, ".text-base.font-bold", "Administrators")
      assert has_element?(comp, "button", "Save Design")
    end

    test "validates certificate design changes on input change", %{
      conn: conn,
      certificate: certificate
    } do
      {:ok, comp, _html} =
        live_component_isolated(conn, DesignTab, %{
          id: "certificate_design_component",
          certificate: certificate,
          read_only: false
        })

      # Simulate a change on the certificate form (triggers the "validate" event)
      comp
      |> element("form#certificate-settings-design-form")
      |> render_change(%{"certificate" => %{"title" => "New Course Title"}})

      # Check that the input has been updated with the new value
      assert has_element?(
               comp,
               "input[name=\"certificate[title]\"][value=\"New Course Title\"]"
             )
    end
  end

  describe "certificate design component read only mode" do
    setup [:setup_certificate]

    test "renders design component correctly and navigate between certificates", %{
      conn: conn,
      certificate: certificate
    } do
      {:ok, comp, _html} =
        live_component_isolated(conn, DesignTab, %{
          id: "certificate_design_component",
          certificate: certificate,
          read_only: true
        })

      # Certificate of completion is displayed by default
      assert element(comp, "iframe") |> render() =~ "Certificate of Completion"
      # The previous button is disabled
      assert has_element?(comp, "button[role=\"prev button\"][disabled]")

      # See next design preview (distinction)
      element(comp, "button[role=\"next button\"]") |> render_click()

      # Certificate with distinction is displayed
      assert element(comp, "iframe") |> render() =~ "Certificate with Distinction"
      # The next button is disabled
      assert has_element?(comp, "button[role=\"next button\"][disabled]")
    end

    test "can use carousel dots to preview different certificates", %{
      conn: conn,
      certificate: certificate
    } do
      {:ok, comp, _html} =
        live_component_isolated(conn, DesignTab, %{
          id: "certificate_design_component",
          certificate: certificate,
          read_only: true
        })

      # Certificate of completion is displayed by default
      assert element(comp, "iframe") |> render() =~ "Certificate of Completion"
      # The current dot in carousel is disabled
      assert has_element?(comp, "button[role=\"carousel prev button\"][disabled]")

      # See next design preview (distinction)
      element(comp, "button[role=\"carousel next button\"]") |> render_click()

      # Certificate with distinction is displayed
      assert element(comp, "iframe") |> render() =~ "Certificate with Distinction"
      # The next button is disabled
      assert has_element?(comp, "button[role=\"carousel next button\"][disabled]")
    end
  end

  defp setup_certificate(_context) do
    certificate = insert(:certificate)
    %{certificate: certificate}
  end
end

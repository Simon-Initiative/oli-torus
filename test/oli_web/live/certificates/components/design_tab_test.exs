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
          certificate: certificate
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
          certificate: certificate
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

  defp setup_certificate(_context) do
    certificate = insert(:certificate)
    %{certificate: certificate}
  end
end

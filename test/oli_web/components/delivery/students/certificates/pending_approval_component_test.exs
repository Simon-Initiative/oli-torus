defmodule OliWeb.Delivery.Students.Certificates.PendingApprovalComponentTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Students.Certificates.PendingApprovalComponent

  describe "pending approval component" do
    test "renders the provided number of pending approvals", %{conn: conn} do
      attrs = %{id: "some_id", pending_approvals: 1}

      {:ok, lcd, _html} = live_component_isolated(conn, PendingApprovalComponent, attrs)

      assert has_element?(lcd, "span#students_pending_certificates_count", "1")
    end

    test "does not render the provided number of pending approvals if it is zero", %{conn: conn} do
      attrs = %{id: "some_id", pending_approvals: 0}

      {:ok, lcd, _html} = live_component_isolated(conn, PendingApprovalComponent, attrs)

      refute has_element?(lcd, "span#students_pending_certificates_count", "0")
    end
  end
end

defmodule OliWeb.Plugs.PlugOrderIntegrationTest do
  use OliWeb.ConnCase
  import Oli.Factory

  alias OliWeb.Plugs.RequireEnrollment
  alias Oli.Plugs.EnforcePaywall
  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  describe "MER-4937: plug order bug - enrollment vs paywall" do
    setup %{conn: conn} do
      # Create a section that requires both enrollment and payment
      section =
        insert(:section, %{
          requires_enrollment: true,
          requires_payment: true,
          registration_open: true,
          amount: Money.new(:USD, 100)
        })

      # Create a user who is NOT enrolled yet
      user =
        insert(:user, independent_learner: false)
        |> Map.merge(%{
          platform_roles: [Lti_1p3.Roles.PlatformRoles.get_role(:institution_learner)]
        })

      conn =
        conn
        |> Plug.Test.init_test_session([])
        |> assign(:current_user, user)
        |> assign(:section, section)
        |> assign(:is_admin, false)

      {:ok, conn: conn, section: section, user: user}
    end

    test "BUG SCENARIO: wrong plug order leads to unauthorized instead of enrollment redirect",
         %{conn: conn, section: _section} do
      # This test represents the BUG scenario where :enforce_paywall runs before :require_enrollment
      # Expected: User gets "not_authorized.html" instead of enrollment redirect
      # This simulates the user accessing: /users/login?section=some_section_slug
      # where the section requires both enrollment and payment

      # WRONG ORDER: enforce_paywall runs FIRST (this was the bug)
      conn_after_paywall = EnforcePaywall.call(conn, [])

      # BUG: Should be halted with "not_authorized" view instead of enrollment redirect
      assert conn_after_paywall.halted == true
      # The EnforcePaywall plug checks if user is enrolled, and since they're not,
      # it returns AccessSummary.not_enrolled() which renders "not_authorized.html"
      assert conn_after_paywall.resp_body =~ "Not authorized"

      # User never gets the chance to enroll because the request was halted
    end

    test "FIXED SCENARIO: correct plug order allows enrollment redirect",
         %{conn: conn, section: section} do
      # This test represents the FIXED scenario where :require_enrollment runs before :enforce_paywall
      # Expected: User gets redirected to enrollment page

      # CORRECT ORDER: require_enrollment runs FIRST (this is the fix)
      conn_after_enrollment = RequireEnrollment.call(conn, [])

      # FIXED: Should be halted with redirect to enrollment page
      assert conn_after_enrollment.halted == true
      # The RequireEnrollment plug sees user is not enrolled but registration_open: true
      # so it redirects to enrollment page
      assert redirected_to(conn_after_enrollment) =~ "/sections/#{section.slug}/enroll"

      # User gets opportunity to enroll instead of seeing unauthorized page
    end

    test "after user enrolls, both plugs should work correctly", %{
      conn: conn,
      section: section,
      user: user
    } do
      # First enroll the user
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      # Now test both plugs in correct order
      # Step 1: RequireEnrollment should pass (user is enrolled)
      conn_after_enrollment = RequireEnrollment.call(conn, [])
      assert conn_after_enrollment.halted == false

      # Step 2: EnforcePaywall should redirect to payment (not "not_authorized")
      conn_after_paywall = EnforcePaywall.call(conn_after_enrollment, [])
      assert conn_after_paywall.halted == true
      # Should redirect to payment page since user is enrolled but hasn't paid
      location = get_resp_header(conn_after_paywall, "location") |> List.first()
      assert location =~ "payment"
    end

    test "INTEGRATION: accessing /sections/section_slug redirects non-enrolled user to /enroll",
         %{conn: conn, section: section, user: user} do
      # This test simulates the actual route access scenario:
      # User tries to access /sections/{section_slug} where section requires enrollment + payment
      # With correct plug order, user should be redirected to enrollment page

      conn =
        conn
        |> log_in_user(user)
        |> get("/sections/#{section.slug}")

      # Should be redirected to enrollment page due to correct plug order
      assert redirected_to(conn) =~ "/sections/#{section.slug}/enroll"
      assert conn.halted == true
    end
  end
end

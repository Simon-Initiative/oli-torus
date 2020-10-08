defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  describe "lti_controller" do
    setup [:create_fixtures]

    test "login post successful", %{conn: conn, registration: registration} do
      body = %{
        "client_id" => registration.client_id,
        "iss" => registration.issuer,
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "target_link_uri" => "https://some-target_link_uri/lti/launch"
      }
      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert redirected_to(conn) =~ "some auth_login_url?"
      assert redirected_to(conn) =~ "client_id=some+client_id"
      assert redirected_to(conn) =~ "login_hint=some-login_hint"
      assert redirected_to(conn) =~ "lti_message_hint=some-lti_message_hint"
      assert redirected_to(conn) =~ "nonce="
      assert redirected_to(conn) =~ "redirect_uri=https%3A%2F%2Fsome-target_link_uri%2Flti%2Flaunch"
      assert redirected_to(conn) =~ "response_mode=form_post"
      assert redirected_to(conn) =~ "response_type=id_token"
      assert redirected_to(conn) =~ "scope=openid"
      assert redirected_to(conn) =~ "state="

      assert get_session(conn, "state") != nil

    end

    test "login get successful", %{conn: conn, registration: registration} do
      body = %{
        "client_id" => registration.client_id,
        "iss" => registration.issuer,
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "target_link_uri" => "https://some-target_link_uri/lti/launch"
      }

      conn = get(conn, Routes.lti_path(conn, :login, body))

      assert redirected_to(conn) =~ "some auth_login_url?"
      assert redirected_to(conn) =~ "client_id=some+client_id"
      assert redirected_to(conn) =~ "login_hint=some-login_hint"
      assert redirected_to(conn) =~ "lti_message_hint=some-lti_message_hint"
      assert redirected_to(conn) =~ "nonce="
      assert redirected_to(conn) =~ "redirect_uri=https%3A%2F%2Fsome-target_link_uri%2Flti%2Flaunch"
      assert redirected_to(conn) =~ "response_mode=form_post"
      assert redirected_to(conn) =~ "response_type=id_token"
      assert redirected_to(conn) =~ "scope=openid"
      assert redirected_to(conn) =~ "state="

      assert get_session(conn, "state") != nil
    end

    test "login post fails on missing registration", %{conn: conn, registration: registration} do
      body = %{
        "client_id" => registration.client_id,
        "iss" => "http://invalid.edu",
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "target_link_uri" => "https://some-target_link_uri/lti/launch"
      }
      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert html_response(conn, 200) =~ "No registration exists for issuer (iss): http://invalid.edu"

    end

  end

  defp create_fixtures(%{conn: conn}) do
    jwk = jwk_fixture()
    institution = institution_fixture()
    registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
    deployment = deployment_fixture(%{registration_id: registration.id})

    %{conn: conn, deployment: deployment, registration: registration, institution: institution}
  end

end

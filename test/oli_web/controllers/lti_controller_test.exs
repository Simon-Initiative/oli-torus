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

      assert html_response(conn, 200) =~ "Welcome to the Open Learning Initiative!"
      assert html_response(conn, 200) =~ "Register Your Institution"

    end

    test "returns developer key json", %{conn: conn} do
      conn = get(conn, Routes.lti_path(conn, :developer_key_json))

      active_jwk = Oli.Lti_1p3.get_active_jwk()

      public_jwk = JOSE.JWK.from_pem(active_jwk.pem) |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()
      |> (fn {_kty, public_jwk} -> public_jwk end).()
      |> Map.put("kid", active_jwk.kid)

      assert json_response(conn, 200) != nil
      assert json_response(conn, 200) |> Map.get("extensions") |> Enum.find(fn %{"platform" => p} -> p == "canvas.instructure.com" end) |> Map.get("privacy_level") =~ "public"
      assert json_response(conn, 200) |> Map.get("title") =~ "OLI Torus"
      assert json_response(conn, 200) |> Map.get("description") =~ "Create, deliver and iteratively improve course content with Torus, through the Open Learning Initiative"
      assert json_response(conn, 200) |> Map.get("oidc_initiation_url") =~ "https://localhost/lti/login"
      assert json_response(conn, 200) |> Map.get("target_link_uri") =~ "https://localhost/lti/launch"
      assert json_response(conn, 200) |> Map.get("public_jwk_url") =~ "https://localhost/.well-known/jwks.json"
      assert json_response(conn, 200) |> Map.get("scopes") == []
      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("kid") == public_jwk["kid"]
      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("n") == public_jwk["n"]
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

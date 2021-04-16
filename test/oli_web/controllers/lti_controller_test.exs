defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Lti_1p3.Platform.PlatformInstance
  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints

  import Mox

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

      assert redirected_to(conn) =~
               "redirect_uri=https%3A%2F%2Fsome-target_link_uri%2Flti%2Flaunch"

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

      assert redirected_to(conn) =~
               "redirect_uri=https%3A%2F%2Fsome-target_link_uri%2Flti%2Flaunch"

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

      # validate still works when a user is already logged in
      user = user_fixture()
      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert html_response(conn, 200) =~ "Welcome to the Open Learning Initiative!"
      assert html_response(conn, 200) =~ "Register Your Institution"
    end

    test "launch successful for valid params and creates deployment on the fly", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, fn "some key_set_url" ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               keys: [
                 platform_jwk.pem
                 |> JOSE.JWK.from_pem()
                 |> JOSE.JWK.to_public()
                 |> JOSE.JWK.to_map()
                 |> (fn {_kty, public_jwk} -> public_jwk end).()
                 |> Map.put("typ", platform_jwk.typ)
                 |> Map.put("alg", platform_jwk.alg)
                 |> Map.put("kid", platform_jwk.kid)
                 |> Map.put("use", "sig")
               ]
             })
         }}
      end)

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti_1p3.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      deployment_id = claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
      registration_id = registration.id

      assert nil ==
               Lti_1p3.Tool.get_registration_deployment(
                 registration.issuer,
                 registration.client_id,
                 deployment_id
               )

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert redirected_to(conn) == Routes.delivery_path(conn, :index)

      assert {%Lti_1p3.Tool.Registration{},
              %Lti_1p3.Tool.Deployment{
                deployment_id: ^deployment_id,
                registration_id: ^registration_id
              }} =
               Lti_1p3.Tool.get_registration_deployment(
                 registration.issuer,
                 registration.client_id,
                 deployment_id
               )
    end

    test "launch handles invalid registration and shows registration form", %{conn: conn} do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, fn "some key_set_url" ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               keys: [
                 platform_jwk.pem
                 |> JOSE.JWK.from_pem()
                 |> JOSE.JWK.to_public()
                 |> JOSE.JWK.to_map()
                 |> (fn {_kty, public_jwk} -> public_jwk end).()
                 |> Map.put("typ", platform_jwk.typ)
                 |> Map.put("alg", platform_jwk.alg)
                 |> Map.put("kid", platform_jwk.kid)
                 |> Map.put("use", "sig")
               ]
             })
         }}
      end)

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti_1p3.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: "some different client_id", aud: "some different issuer")
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert html_response(conn, 200) =~ "Welcome to the Open Learning Initiative!"
      assert html_response(conn, 200) =~ "Register Your Institution"
    end

    test "authorize_redirect get successful for user", %{conn: conn} do
      user = user_fixture()
      {:ok, %LoginHint{value: login_hint}} = LoginHints.create_login_hint(user.id)
      target_link_uri = "some-valid-url"
      nonce = "some-nonce"
      client_id = "some-client-id"
      state = "some-state"
      lti_message_hint = "some-lti-message-hint"

      {:ok, %PlatformInstance{}} =
        Lti_1p3.Platform.create_platform_instance(%PlatformInstance{
          name: "some-platform",
          target_link_uri: target_link_uri,
          client_id: client_id,
          login_url: "some-login-url",
          keyset_url: "some-keyset-url",
          redirect_uris: "some-valid-url"
        })

      params = %{
        "client_id" => client_id,
        "login_hint" => login_hint,
        "lti_message_hint" => lti_message_hint,
        "nonce" => nonce,
        "prompt" => "none",
        "redirect_uri" => target_link_uri,
        "response_mode" => "form_post",
        "response_type" => "id_token",
        "scope" => "openid",
        "state" => state
      }

      conn = Pow.Plug.assign_current_user(conn, user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = get(conn, Routes.lti_path(conn, :authorize_redirect, params))

      assert html_response(conn, 200) =~ "You are being redirected..."

      assert html_response(conn, 200) =~
               "<form name=\"post_redirect\" action=\"#{target_link_uri}\" method=\"post\">"
    end

    test "authorize_redirect get successful for author", %{conn: conn} do
      author = author_fixture()
      {:ok, %LoginHint{value: login_hint}} = LoginHints.create_login_hint(author.id, "author")
      target_link_uri = "some-valid-url"
      nonce = "some-nonce"
      client_id = "some-client-id"
      state = "some-state"
      lti_message_hint = "some-lti-message-hint"

      {:ok, %PlatformInstance{}} =
        Lti_1p3.Platform.create_platform_instance(%PlatformInstance{
          name: "some-platform",
          target_link_uri: target_link_uri,
          client_id: client_id,
          login_url: "some-login-url",
          keyset_url: "some-keyset-url",
          redirect_uris: "some-valid-url"
        })

      params = %{
        "client_id" => client_id,
        "login_hint" => login_hint,
        "lti_message_hint" => lti_message_hint,
        "nonce" => nonce,
        "prompt" => "none",
        "redirect_uri" => target_link_uri,
        "response_mode" => "form_post",
        "response_type" => "id_token",
        "scope" => "openid",
        "state" => state
      }

      conn =
        Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      conn = get(conn, Routes.lti_path(conn, :authorize_redirect, params))

      assert html_response(conn, 200) =~ "You are being redirected..."

      assert html_response(conn, 200) =~
               "<form name=\"post_redirect\" action=\"#{target_link_uri}\" method=\"post\">"
    end

    test "returns developer key json", %{conn: conn} do
      conn = get(conn, Routes.lti_path(conn, :developer_key_json))

      {:ok, active_jwk} = Lti_1p3.get_active_jwk()

      public_jwk =
        JOSE.JWK.from_pem(active_jwk.pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> (fn {_kty, public_jwk} -> public_jwk end).()
        |> Map.put("kid", active_jwk.kid)

      assert json_response(conn, 200) != nil

      assert json_response(conn, 200)
             |> Map.get("extensions")
             |> Enum.find(fn %{"platform" => p} -> p == "canvas.instructure.com" end)
             |> Map.get("privacy_level") =~ "public"

      assert json_response(conn, 200) |> Map.get("title") =~ "OLI Torus"

      assert json_response(conn, 200) |> Map.get("description") =~
               "Create, deliver and iteratively improve course content through the Open Learning Initiative"

      assert json_response(conn, 200) |> Map.get("oidc_initiation_url") =~
               "https://localhost/lti/login"

      assert json_response(conn, 200) |> Map.get("target_link_uri") =~
               "https://localhost/lti/launch"

      assert json_response(conn, 200) |> Map.get("public_jwk_url") =~
               "https://localhost/.well-known/jwks.json"

      assert json_response(conn, 200) |> Map.get("scopes") == [
               "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
               "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly",
               "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
               "https://purl.imsglobal.org/spec/lti-ags/scope/score",
               "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"
             ]

      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("kid") ==
               public_jwk["kid"]

      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("n") == public_jwk["n"]
    end
  end

  defp create_fixtures(%{conn: conn}) do
    jwk = jwk_fixture()
    institution = institution_fixture()
    registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
    deployment = deployment_fixture(%{registration_id: registration.id})

    %{
      conn: conn,
      jwk: jwk,
      deployment: deployment,
      registration: registration,
      institution: institution
    }
  end
end

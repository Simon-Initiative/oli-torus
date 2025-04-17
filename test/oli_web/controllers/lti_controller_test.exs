defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Lti_1p3.Platform.{LoginHint, LoginHints}
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Institutions
  alias Oli.Delivery.Sections
  alias Oli.Accounts.User
  alias Oli.Lti.PlatformExternalTools

  import Mox
  import Oli.Factory

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

      assert html_response(conn, 200) =~ "Welcome to"
      assert html_response(conn, 200) =~ "Register Your Institution"

      # validate still works when a user is already logged in
      user = user_fixture()

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert html_response(conn, 200) =~ "Welcome to"
      assert html_response(conn, 200) =~ "Register Your Institution"

      # form contains a required text input for deployment id
      assert html_response(conn, 200) =~
               "<input class=\"deployment_id form-control \" id=\"pending_registration_deployment_id\" name=\"pending_registration[deployment_id]\" placeholder=\"Deployment ID\" required type=\"text\">"
    end

    test "registration form pre-populates deployment_id if it was included in oidc params", %{
      conn: conn,
      registration: registration
    } do
      body = %{
        "client_id" => registration.client_id,
        "iss" => "http://invalid.edu",
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "target_link_uri" => "https://some-target_link_uri/lti/launch",
        "lti_deployment_id" => "prepopulated_deployment_id"
      }

      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert html_response(conn, 200) =~ "Welcome to Torus!"
      assert html_response(conn, 200) =~ "Register Your Institution"

      # validate still works when a user is already logged in
      user = user_fixture()

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert html_response(conn, 200) =~ "Welcome to Torus!"
      assert html_response(conn, 200) =~ "Register Your Institution"

      # form contains a hidden input with value "prepopulated_deployment_id"
      assert html_response(conn, 200) =~ "value=\"prepopulated_deployment_id\""
    end

    test "show registration page when deployment doesnt exist", %{
      conn: conn,
      registration: registration,
      deployment: deployment
    } do
      {:ok, _} = Institutions.delete_deployment(deployment)

      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, mock_keyset_endpoint("some key_set_url", platform_jwk))

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      deployment_id = claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

      assert nil ==
               Lti_1p3.Tool.get_registration_deployment(
                 registration.issuer,
                 registration.client_id,
                 deployment_id
               )

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert html_response(conn, 200) =~ "Welcome to Torus!"
      assert html_response(conn, 200) =~ "Register Your Institution"

      # known deployment id is pre-populated and embedded in the form
      assert html_response(conn, 200) =~ "value=\"#{deployment.deployment_id}\""
    end

    test "launch successful for valid params and creates lms user", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, mock_keyset_endpoint("some key_set_url", platform_jwk))

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert redirected_to(conn) == Routes.delivery_path(conn, :index)
    end

    test "launch successful for valid params and updates lms user", %{
      conn: conn,
      registration: registration,
      institution: institution
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, mock_keyset_endpoint("some key_set_url", platform_jwk))

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      # Create users with same sub.
      sub = Oli.Lti.TestHelpers.security_detail_data()["sub"]
      email = Oli.Lti.TestHelpers.user_detail_data()["email"]

      lti_user = insert(:user, %{sub: sub, email: email})
      another_lti_user = insert(:user, %{sub: sub, email: "another_lti_user@email.com"})

      # Create another institution and sections.
      another_institution = insert(:institution)
      lti_section = insert(:section, institution: institution)
      another_section = insert(:section, institution: another_institution)

      # Enroll users to sections
      Sections.enroll(lti_user.id, lti_section.id, [ContextRoles.get_role(:context_learner)])

      Sections.enroll(another_lti_user.id, another_section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert redirected_to(conn) == Routes.delivery_path(conn, :index)

      # Check that the user is the same as lti_user, but has some new field defined (it was
      # updated).
      conn = OliWeb.UserAuth.fetch_current_user(conn, [])
      logged_user = conn.assigns[:current_user]
      new_name = Oli.Lti.TestHelpers.user_detail_data()["name"]

      assert logged_user.id == lti_user.id
      assert logged_user.name == new_name

      # Check that the other user was ignored.
      refute Oli.Repo.get_by(User, email: another_lti_user.email).name == new_name
    end

    test "launch successful when aud claim is a list", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, mock_keyset_endpoint("some key_set_url", platform_jwk))

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer)
        |> Joken.Config.add_claim("aud", fn -> [registration.client_id] end)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert redirected_to(conn) == Routes.delivery_path(conn, :index)
    end

    test "launch successful for valid params with no email", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 2, mock_keyset_endpoint("some key_set_url", platform_jwk))

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")
        |> Map.delete("email")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert redirected_to(conn) == Routes.delivery_path(conn, :index)
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
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")

      {:ok, claims} =
        Joken.Config.default_claims(iss: "some different client_id", aud: "some different issuer")
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))

      assert html_response(conn, 200) =~ "Welcome to"
      assert html_response(conn, 200) =~ "Register Your Institution"
    end

    test "authorize_redirect get successful for user", %{conn: conn} do
      user = user_fixture()

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, "section:some_section")

      target_link_uri = "some-valid-url"
      nonce = "some-nonce"
      client_id = "some-client-id"
      state = "some-state"
      lti_message_hint = "some-lti-message-hint"

      {:ok, {_, _, _}} =
        PlatformExternalTools.register_lti_external_tool_activity(%{
          "name" => "some-platform",
          "description" => "some-description",
          "target_link_uri" => "target_link_uri",
          "client_id" => "some-client-id",
          "login_url" => "some-login-url",
          "keyset_url" => "some-keyset-url",
          "redirect_uris" => "some-valid-url"
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

      conn = log_in_user(conn, user) |> Plug.Conn.assign(:current_user, user)

      conn = get(conn, Routes.lti_path(conn, :authorize_redirect, params))

      assert html_response(conn, 200) =~ "You are being redirected..."

      assert html_response(conn, 200) =~
               "<form name=\"post_redirect\" action=\"#{target_link_uri}\" method=\"post\">"
    end

    test "authorize_redirect get successful for author", %{conn: conn} do
      author = author_fixture()

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(author.id, "project:some_project")

      target_link_uri = "some-valid-url"
      nonce = "some-nonce"
      client_id = "some-client-id"
      state = "some-state"
      lti_message_hint = "some-lti-message-hint"

      {:ok, {_, _, _}} =
        PlatformExternalTools.register_lti_external_tool_activity(%{
          "name" => "some-platform",
          "description" => "some-description",
          "target_link_uri" => "target_link_uri",
          "client_id" => "some-client-id",
          "login_url" => "some-login-url",
          "keyset_url" => "some-keyset-url",
          "redirect_uris" => "some-valid-url"
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

      conn = log_in_author(conn, author)

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
               "Create, deliver and iteratively improve course content"

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

      %{"extensions" => [%{"settings" => %{"placements" => placements}} | _]} =
        json_response(conn, 200)

      assert placements == [
               %{
                 "icon_url" => "https://localhost/branding/prod/oli_torus_icon.png",
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "link_selection"
               },
               %{
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "assignment_selection"
               },
               %{
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "course_navigation",
                 "default" => "disabled",
                 "windowTarget" => "_blank"
               }
             ]

      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("kid") ==
               public_jwk["kid"]

      assert json_response(conn, 200) |> Map.get("public_jwk") |> Map.get("n") == public_jwk["n"]
    end

    test "returns developer key json with course navigation enabled", %{conn: conn} do
      conn =
        get(
          conn,
          Routes.lti_path(conn, :developer_key_json, course_navigation_default: "enabled")
        )

      %{"extensions" => [%{"settings" => %{"placements" => placements}} | _]} =
        json_response(conn, 200)

      assert placements == [
               %{
                 "icon_url" => "https://localhost/branding/prod/oli_torus_icon.png",
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "link_selection"
               },
               %{
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "assignment_selection"
               },
               %{
                 "message_type" => "LtiResourceLinkRequest",
                 "placement" => "course_navigation",
                 "default" => "enabled",
                 "windowTarget" => "_blank"
               }
             ]
    end
  end

  defp create_fixtures(%{conn: conn}) do
    jwk = jwk_fixture()
    institution = institution_fixture()
    registration = registration_fixture(%{tool_jwk_id: jwk.id})

    deployment =
      deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

    %{
      conn: conn,
      jwk: jwk,
      deployment: deployment,
      registration: registration,
      institution: institution
    }
  end

  defp mock_keyset_endpoint(url, platform_jwk) do
    fn ^url ->
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
    end
  end
end

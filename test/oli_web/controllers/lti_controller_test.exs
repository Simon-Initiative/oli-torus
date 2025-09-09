defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Lti_1p3.Platform.{LoginHint, LoginHints}
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Institutions
  alias Oli.Delivery.Sections
  alias Oli.Accounts.User
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Delivery.Sections
  alias Oli.Test.MockHTTP

  import Mox
  import Oli.Factory

  setup :verify_on_exit!
  setup :set_mox_global

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
      |> expect(:get, 1, mock_keyset_endpoint("some key_set_url", platform_jwk))

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
      |> expect(:get, 1, mock_keyset_endpoint("some key_set_url", platform_jwk))

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

      assert html_response(conn, 200) =~ "This course section is not available"
    end

    test "launch successful for valid params and updates lms user", %{
      conn: conn,
      registration: registration,
      institution: institution
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 1, mock_keyset_endpoint("some key_set_url", platform_jwk))

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

      assert redirected_to(conn) =~ "/workspaces/student"

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
      |> expect(:get, 1, mock_keyset_endpoint("some key_set_url", platform_jwk))

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

      assert html_response(conn, 200) =~ "This course section is not available"
    end

    test "launch successful for valid params with no email", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()

      Oli.Test.MockHTTP
      |> expect(:get, 1, mock_keyset_endpoint("some key_set_url", platform_jwk))

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

      assert html_response(conn, 200) =~ "This course section is not available"
    end

    test "launch handles invalid registration and shows registration form", %{conn: conn} do
      platform_jwk = jwk_fixture()

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
      section = insert(:section)

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(user.id, %{
          "section" => section.slug,
          "resource_id" => 1
        })

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
      project = insert(:project)

      {:ok, %LoginHint{value: login_hint}} =
        LoginHints.create_login_hint(author.id, %{
          "project" => project.slug,
          "resource_id" => "some_resource_id"
        })

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
  end

  describe "deep_link" do
    setup [:setup_section]

    defp assert_deep_link_error_response(resp, expected_error_text) do
      # Verify HTML error response contains error message
      assert resp =~ "Deep Linking Failed"

      if expected_error_text do
        assert resp =~ expected_error_text
      end

      # Verify error postMessage JavaScript is included
      assert resp =~ "window.parent.postMessage"
      assert resp =~ "lti_deep_linking_response"
      assert resp =~ "status: 'error'"
    end

    defp generate_deep_linking_jwt(client_id, key, kid, claims \\ %{}) do
      now = DateTime.utc_now() |> DateTime.to_unix()

      base_claims = %{
        "iss" => client_id,
        "aud" => Oli.Utils.get_base_url(),
        "iat" => now,
        "exp" => now + 3600,
        "jti" => UUID.uuid4(),
        "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiDeepLinkingResponse",
        "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => [
          %{
            "type" => "ltiResourceLink",
            "title" => "Test Resource",
            "text" => "A test resource for deep linking",
            "url" => "https://example.com/resource/123",
            "custom" => %{
              "param1" => "value1",
              "param2" => "value2"
            }
          }
        ]
      }

      final_claims = Map.merge(base_claims, claims)

      jwk = JOSE.JWK.from_pem(key)

      {_, jwt} =
        JOSE.JWT.sign(
          jwk,
          %{"alg" => "RS256", "kid" => kid},
          final_claims
        )
        |> JOSE.JWS.compact()

      jwt
    end

    test "successfully processes valid deep linking response", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      # Insert a platform instance
      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      # Mock HTTP request to fetch the keyset
      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      jwt = generate_deep_linking_jwt(client_id, key_pem, "test-kid")

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 200)

      # Verify HTML response contains success message
      assert resp =~ "Resource Selected Successfully"
      assert resp =~ "Test Resource"
      # Verify postMessage JavaScript is included
      assert resp =~ "window.parent.postMessage"
      assert resp =~ "lti_deep_linking_response"
      assert resp =~ "lti_close_modal"
    end

    @tag capture_log: true
    test "returns 400 for invalid JWT", %{conn: conn, section: section, activity_id: activity_id} do
      params = %{
        "JWT" => "invalid.jwt.token"
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "invalid_deep_linking_jwt")
    end

    @tag capture_log: true
    test "returns 400 for JWT with wrong message type", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      # Generate JWT with wrong message type
      jwt =
        generate_deep_linking_jwt(client_id, key_pem, "test-kid", %{
          "https://purl.imsglobal.org/spec/lti/claim/message_type" => "LtiResourceLinkRequest"
        })

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "invalid_deep_linking_jwt")
    end

    @tag capture_log: true
    test "returns 400 for JWT with wrong audience", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      # Generate JWT with wrong audience
      jwt =
        generate_deep_linking_jwt(client_id, key_pem, "test-kid", %{
          "aud" => "https://wrong-audience.com"
        })

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "invalid_deep_linking_jwt")
    end

    test "returns 400 for JWT with multiple content items", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      # Generate JWT with multiple content items
      jwt =
        generate_deep_linking_jwt(client_id, key_pem, "test-kid", %{
          "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => [
            %{
              "type" => "ltiResourceLink",
              "title" => "Test Resource 1",
              "url" => "https://example.com/resource/1"
            },
            %{
              "type" => "ltiResourceLink",
              "title" => "Test Resource 2",
              "url" => "https://example.com/resource/2"
            }
          ]
        })

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "Expected exactly one content item, got 2")
    end

    test "returns 400 for JWT with no content items", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      # Generate JWT with no content items
      jwt =
        generate_deep_linking_jwt(client_id, key_pem, "test-kid", %{
          "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => []
        })

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "Expected exactly one content item, got 0")
    end

    test "returns 400 for content item with wrong type", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      # Generate JWT with wrong content item type
      jwt =
        generate_deep_linking_jwt(client_id, key_pem, "test-kid", %{
          "https://purl.imsglobal.org/spec/lti-dl/claim/content_items" => [
            %{
              "type" => "file",
              "title" => "Test File",
              "url" => "https://example.com/file.pdf"
            }
          ]
        })

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(
        resp,
        "Expected content item type to be &#39;ltiResourceLink&#39"
      )
    end

    test "returns 400 for non-existent section", %{conn: conn, activity_id: activity_id} do
      client_id = "test-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      public_jwk =
        JOSE.JWK.from_pem(key_pem)
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> elem(1)
        |> Map.put("kid", "test-kid")

      keyset_url = "https://some-tool.example.edu/.well-known/jwks.json"

      insert(:platform_instance, %{
        client_id: client_id,
        keyset_url: keyset_url
      })

      MockHTTP
      |> expect(:get, fn ^keyset_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [public_jwk]})
         }}
      end)

      jwt = generate_deep_linking_jwt(client_id, key_pem, "test-kid")

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/non-existent-section/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "section_not_found")
    end

    @tag capture_log: true
    test "returns 400 for JWT without platform instance", %{
      conn: conn,
      section: section,
      activity_id: activity_id
    } do
      client_id = "non-existent-client-id"
      key_pem = File.read!("test/support/fixtures/test_rsa_private.pem")

      jwt = generate_deep_linking_jwt(client_id, key_pem, "test-kid")

      params = %{
        "JWT" => jwt
      }

      conn = post(conn, ~p"/lti/deep_link/#{section.slug}/#{activity_id}", params)
      resp = html_response(conn, 400)

      assert_deep_link_error_response(resp, "invalid_deep_linking_jwt")
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

  defp create_lti_external_tool_activity() do
    attrs = %{
      "client_id" => "some client_id",
      "custom_params" => "some custom_params",
      "description" => "some description",
      "keyset_url" => "some keyset_url",
      "login_url" => "some login_url",
      "name" => "some name",
      "redirect_uris" => "some redirect_uris",
      "target_link_uri" => "some target_link_uri"
    }

    PlatformExternalTools.register_lti_external_tool_activity(attrs)
  end

  def setup_section(%{conn: conn}) do
    {:ok, seeds} = setup_project(%{conn: conn})

    {:ok, pub1} = Publishing.publish_project(seeds.project, "some changes", seeds.author.id)

    {:ok, section} =
      Sections.create_section(%{
        title: "3",
        registration_open: true,
        open_and_free: true,
        context_id: UUID.uuid4(),
        institution_id: seeds.institution.id,
        base_project_id: seeds.project.id,
        analytics_version: :v1
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(pub1)

    student = user_fixture(%{independent_learner: false})

    Sections.enroll(student.id, section.id, [
      Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
    ])

    conn =
      log_in_user(
        conn,
        student
      )

    {:ok,
     Map.merge(seeds, %{
       conn: conn,
       section: section,
       student: student
     })}
  end

  def setup_project(%{conn: conn}) do
    {:ok, {_platform_instance, activity_registration, _deployment}} =
      create_lti_external_tool_activity()

    seeds = Oli.Seeder.base_project_with_resource2()

    project = Map.get(seeds, :project)
    revision = Map.get(seeds, :revision1)
    author = Map.get(seeds, :author)

    content = %{
      "openInNewTab" => "true",
      "authoring" => %{
        "parts" => []
      }
    }

    {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    {:ok, {%{slug: slug2, resource_id: activity_id2}, _}} =
      ActivityEditor.create(project.slug, activity_registration.slug, author, content, [])

    seeds = Map.put(seeds, :activity_id, activity_id) |> Map.put(:activity_id2, activity_id2)

    update = %{
      "content" => %{
        "version" => "0.1.0",
        "model" => [
          %{
            "type" => "activity-reference",
            "id" => "1",
            "activitySlug" => slug
          },
          %{
            "type" => "activity-reference",
            "id" => "2",
            "activitySlug" => slug2
          }
        ]
      }
    }

    PageEditor.acquire_lock(project.slug, revision.slug, author.email)
    assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

    conn =
      log_in_author(
        conn,
        seeds.author
      )

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end

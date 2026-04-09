defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Lti_1p3.Platform.{LoginHint, LoginHints}
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Institutions
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Authoring.Editing.{ActivityEditor, PageEditor}
  alias Oli.Publishing
  alias Oli.Test.MockHTTP

  import Mox
  import Oli.Factory
  import ExUnit.CaptureLog

  @telemetry_prefix [:oli, :lti]

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

    test "session-backed login and launch succeed even when lti storage target is advertised", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()
      cache_keyset_for_registration(registration, platform_jwk)

      body = %{
        "client_id" => registration.client_id,
        "iss" => registration.issuer,
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "lti_storage_target" => "post_message_forwarding",
        "target_link_uri" => "https://some-target_link_uri/lti/launch"
      }

      conn = post(conn, Routes.lti_path(conn, :login, body))
      redirect_url = redirected_to(conn)
      state = redirect_query_param(redirect_url, "state")

      assert state == get_session(conn, "state")

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

    test "login post fails on missing registration and redirects to register_form", %{
      conn: conn,
      registration: registration
    } do
      body = %{
        "client_id" => registration.client_id,
        "iss" => "http://invalid.edu",
        "login_hint" => "some-login_hint",
        "lti_message_hint" => "some-lti_message_hint",
        "target_link_uri" => "https://some-target_link_uri/lti/launch"
      }

      conn = post(conn, Routes.lti_path(conn, :login, body))

      redirect_path = redirected_to(conn)

      assert redirect_path =~ "/lti/register_form?"
      assert redirect_path =~ "issuer=http%3A%2F%2Finvalid.edu"
      assert redirect_path =~ "client_id=#{URI.encode_www_form(registration.client_id)}"

      # validate still works when a user is already logged in
      user = user_fixture()

      conn =
        recycle(conn)
        |> log_in_user(user)

      conn = post(conn, Routes.lti_path(conn, :login, body))

      assert redirected_to(conn) =~ "issuer=http%3A%2F%2Finvalid.edu"
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

      redirect_path = redirected_to(conn)
      assert redirect_path =~ "deployment_id=prepopulated_deployment_id"

      conn = recycle(conn) |> get(redirect_path)

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

      # Pre-cache the keyset since we no longer fetch on-demand
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

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

      redirect_path = redirected_to(conn)
      assert redirect_path =~ "/lti/register_form?"
      assert redirect_path =~ "issuer=#{URI.encode_www_form(registration.issuer)}"
      assert redirect_path =~ "client_id=#{URI.encode_www_form(registration.client_id)}"
      assert redirect_path =~ "deployment_id=#{deployment_id}"

      conn = recycle(conn) |> get(redirect_path)

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

      # Pre-cache the keyset since we no longer fetch on-demand
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

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

    test "launch redirect uses the current launch attempt instead of latest durable lti params",
         %{
           conn: conn,
           registration: registration,
           deployment: deployment,
           institution: _institution
         } do
      platform_jwk = jwk_fixture()
      cache_keyset_for_registration(registration, platform_jwk)

      current_section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "10337",
          status: :active
        )

      stale_section =
        insert(:section,
          lti_1p3_deployment: deployment,
          context_id: "stale-context",
          status: :active
        )

      stale_user = insert(:user, sub: Oli.Lti.TestHelpers.security_detail_data()["sub"])

      insert(:lti_params,
        user_id: stale_user.id,
        issuer: registration.issuer,
        client_id: registration.client_id,
        deployment_id: deployment.deployment_id,
        context_id: stale_section.context_id,
        sub: stale_user.sub,
        params: %{
          "iss" => registration.issuer,
          "aud" => [registration.client_id],
          "sub" => stale_user.sub,
          "exp" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
          "https://purl.imsglobal.org/spec/lti/claim/context" => %{
            "id" => stale_section.context_id
          },
          "https://purl.imsglobal.org/spec/lti/claim/roles" => [
            "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
          ],
          "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
        },
        updated_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      )

      state = "redirect-authority-state"

      conn =
        init_launch_session(conn, state,
          issuer: registration.issuer,
          client_id: registration.client_id,
          deployment_id: deployment.deployment_id
        )

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")
        |> put_in(
          ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
          current_section.context_id
        )
        |> put_in(
          ["https://purl.imsglobal.org/spec/lti/claim/context", "title"],
          current_section.title
        )
        |> put_in(
          ["https://purl.imsglobal.org/spec/lti/claim/roles"],
          ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"]
        )

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))
      assert redirected_to(conn) == "/sections/#{current_section.slug}"
      refute redirected_to(conn) == "/sections/#{stale_section.slug}/manage"
    end

    test "launch successful for valid params and updates lms user", %{
      conn: conn,
      registration: registration,
      institution: institution
    } do
      platform_jwk = jwk_fixture()

      # Pre-cache the keyset since we no longer fetch on-demand
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

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

      lti_user = insert(:user, %{sub: sub, email: email, independent_learner: false})

      another_lti_user =
        insert(:user, %{sub: sub, email: "another_lti_user@email.com", independent_learner: false})

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
      assert html_response(conn, 200) =~ "This course section is not available"

      # Check that the user is the same as lti_user, but has some new field defined (it was
      # updated).
      logged_user = Oli.Repo.get!(User, lti_user.id)
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

      # Pre-cache the keyset since we no longer fetch on-demand
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

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

      # Pre-cache the keyset since we no longer fetch on-demand
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

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

    test "launch handles invalid registration and redirects to registration form", %{conn: conn} do
      handler_id = attach_handler([@telemetry_prefix ++ [:registration_handoff]])
      platform_jwk = jwk_fixture()

      state = "some-state"
      conn = init_launch_session(conn, state)

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

      redirect_path = redirected_to(conn)
      assert redirect_path =~ "/lti/register_form?"
      assert redirect_path =~ "issuer=some+different+client_id"
      assert redirect_path =~ "client_id=some+different+issuer"

      assert_receive {:telemetry_event, [:oli, :lti, :registration_handoff], %{count: 1}, meta}
      assert meta.classification == :invalid_registration
      assert meta.transport_method == :session_storage

      conn = recycle(conn) |> get(redirect_path)

      assert html_response(conn, 200) =~ "Welcome to"
      assert html_response(conn, 200) =~ "Register Your Institution"

      detach_handler(handler_id)
    end

    test "launch renders stable error for mismatched legacy session state", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = Plug.Test.init_test_session(conn, state: "different-state")

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

      log =
        capture_log(fn ->
          conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))
          response = html_response(conn, 400)

          assert response =~ "Launch State Did Not Match"
          refute response =~ "data-phx-session"
        end)

      assert log =~ "LTI launch rendered error"
      assert log =~ "classification=:mismatched_state"
      assert log =~ "transport_method=:session_storage"
    end

    test "launch validation failure logs kid diagnostics", %{
      conn: conn,
      registration: registration
    } do
      platform_jwk = jwk_fixture()
      cache_keyset_for_registration(registration, platform_jwk)

      state = "some-state"
      conn = init_launch_session(conn, state)

      custom_header = %{"kid" => platform_jwk.kid}
      signer = Joken.Signer.create("RS256", %{"pem" => platform_jwk.pem}, custom_header)

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> Map.delete("iss")
        |> Map.delete("aud")
        |> Map.delete("https://purl.imsglobal.org/spec/lti/claim/message_type")

      {:ok, claims} =
        Joken.Config.default_claims(iss: registration.issuer, aud: registration.client_id)
        |> Joken.generate_claims(claims)

      {:ok, id_token, _claims} = Joken.encode_and_sign(claims, signer)

      log =
        capture_log(fn ->
          conn = post(conn, Routes.lti_path(conn, :launch, %{state: state, id_token: id_token}))
          assert html_response(conn, 400) =~ "LTI Launch Could Not Be Validated"
        end)

      assert log =~ "kid="
      assert log =~ "key_set_url="
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

      refute html_response(conn, 200) =~ "phx-"
      refute html_response(conn, 200) =~ "/live"
      refute html_response(conn, 200) =~ "/js/app.js"
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

      refute html_response(conn, 200) =~ "phx-"
      refute html_response(conn, 200) =~ "/live"
      refute html_response(conn, 200) =~ "/js/app.js"
    end

    test "show_registration_form displays registration page with params from URL", %{
      conn: conn
    } do
      conn =
        get(
          conn,
          "/lti/register_form?issuer=http%3A%2F%2Ftest-issuer.edu&client_id=test-client-id&deployment_id=test-deployment-id"
        )

      assert html_response(conn, 200) =~ "Welcome to Torus!"
      assert html_response(conn, 200) =~ "Register Your Institution"
      assert html_response(conn, 200) =~ "value=\"test-deployment-id\""
    end

    test "show_registration_form handles missing URL params gracefully", %{conn: conn} do
      conn = get(conn, "/lti/register_form")
      response = html_response(conn, 200)

      assert response =~ "Welcome to Torus!"
      assert response =~ "Register Your Institution"
      assert response =~ ~s(const normalizedIssuer = typeof issuer === "string" ? issuer : "";)
    end

    test "show_registration_form with pending registration shows pending message from URL params",
         %{
           conn: conn
         } do
      # Create a pending registration first
      pending_registration_attrs = %{
        "issuer" => "http://pending-issuer.edu",
        "client_id" => "pending-client-id",
        "name" => "Pending Institution",
        "institution_url" => "http://pending.edu",
        "institution_email" => "contact@pending.edu",
        "country_code" => "US",
        "key_set_url" => "http://pending.edu/jwks",
        "auth_token_url" => "http://pending.edu/token",
        "auth_login_url" => "http://pending.edu/login",
        "auth_server" => "http://pending.edu",
        "deployment_id" => "pending-deployment"
      }

      {:ok, _pending} = Institutions.create_pending_registration(pending_registration_attrs)

      conn =
        get(
          conn,
          "/lti/register_form?issuer=http%3A%2F%2Fpending-issuer.edu&client_id=pending-client-id&deployment_id=pending-deployment"
        )

      assert html_response(conn, 200) =~ "Pending Institution"
    end

    test "show_registration_form can be refreshed without session reconstruction", %{conn: conn} do
      path =
        "/lti/register_form?issuer=http%3A%2F%2Frefresh-issuer.edu&client_id=refresh-client-id&deployment_id=refresh-deployment-id"

      first_conn = get(conn, path)
      second_conn = recycle(first_conn) |> get(path)

      assert html_response(first_conn, 200) =~ "Register Your Institution"
      assert html_response(second_conn, 200) =~ "Register Your Institution"
      assert html_response(second_conn, 200) =~ "value=\"refresh-deployment-id\""
    end

    test "request_registration invalid submit re-renders with posted handoff values", %{
      conn: conn
    } do
      recaptcha_ok()

      conn =
        post(conn, Routes.lti_path(conn, :request_registration), %{
          "g-recaptcha-response" => "valid",
          "pending_registration" => %{
            "issuer" => "http://posted-issuer.edu",
            "client_id" => "posted-client-id",
            "deployment_id" => "posted-deployment-id"
          }
        })

      response = html_response(conn, 200)

      assert response =~ "Register Your Institution"
      assert response =~ ~s(value="http://posted-issuer.edu")
      assert response =~ ~s(value="posted-client-id")
      assert response =~ ~s(value="posted-deployment-id")
    end

    test "request_registration rejects invalid recaptcha and re-renders posted values", %{
      conn: conn
    } do
      recaptcha_fail()

      conn =
        post(conn, Routes.lti_path(conn, :request_registration), %{
          "g-recaptcha-response" => "invalid",
          "pending_registration" => %{
            "issuer" => "http://posted-issuer.edu",
            "client_id" => "posted-client-id",
            "deployment_id" => "posted-deployment-id",
            "name" => "Posted University",
            "institution_url" => "https://posted.example.edu",
            "institution_email" => "admin@posted.example.edu",
            "country_code" => "US",
            "key_set_url" => "https://posted.example.edu/keyset",
            "auth_token_url" => "https://posted.example.edu/token",
            "auth_login_url" => "https://posted.example.edu/login",
            "auth_server" => "https://posted.example.edu/auth"
          }
        })

      response = html_response(conn, 200)

      assert response =~ "reCAPTCHA failed, please try again"
      assert response =~ ~s(value="http://posted-issuer.edu")
      assert response =~ ~s(value="posted-client-id")
      assert response =~ ~s(value="posted-deployment-id")
      assert response =~ ~s(value="Posted University")
    end
  end

  defp init_launch_session(conn, state, _attrs \\ []) do
    Plug.Test.init_test_session(conn, state: state)
  end

  defp redirect_query_param(redirect_url, key) do
    redirect_url
    |> URI.parse()
    |> Map.get(:query, "")
    |> URI.decode_query()
    |> Map.get(key)
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

  defp cache_keyset_for_registration(registration, platform_jwk) do
    # Convert JWK to map format expected by JWKS
    public_jwk_map =
      platform_jwk.pem
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()
      |> (fn {_kty, public_jwk} -> public_jwk end).()
      |> Map.put("typ", platform_jwk.typ)
      |> Map.put("alg", platform_jwk.alg)
      |> Map.put("kid", platform_jwk.kid)
      |> Map.put("use", "sig")

    # Cache the keyset in ETS
    Oli.Lti.KeysetCache.put_keyset(registration.key_set_url, [public_jwk_map], 3600)
  end

  defp attach_handler(events) do
    handler_id = "lti-controller-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end

  defp detach_handler(handler_id), do: :telemetry.detach(handler_id)

  defp recaptcha_ok do
    Mox.expect(Oli.Test.RecaptchaMock, :verify, fn _ -> {:success, true} end)
  end

  defp recaptcha_fail do
    Mox.expect(Oli.Test.RecaptchaMock, :verify, fn _ -> {:success, false} end)
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

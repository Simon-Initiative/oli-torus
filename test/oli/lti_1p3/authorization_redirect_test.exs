defmodule Oli.Lti_1p3.AuthorizationRedirectTest do
  use Oli.DataCase

  import Oli.Lti_1p3.TestHelpers
  import Mox

  alias Oli.Lti_1p3.AuthorizationRedirect
  alias Oli.Lti_1p3.MockHTTPoison
  alias Oli.Lti_1p3.PlatformInstances
  alias Oli.Lti_1p3.LoginHint
  alias Oli.Lti_1p3.LoginHints

  describe "authorize_redirect" do
    test "authorizes a valid redirect request" do
      %{
        conn: conn,
        state: state,
        params: params,
        target_link_uri: target_link_uri,
        user: user,
      } = generate_lti_platform_stubs()

      assert {:ok, ^target_link_uri, ^state, id_token} = AuthorizationRedirect.authorize_redirect(params, user)

      # validate the id_token returned is signed correctly
      active_jwk = Oli.Lti_1p3.Utils.get_active_jwk()
      MockHTTPoison
      |> expect(:get, fn _url -> mock_get_jwk_keys(active_jwk) end)

      assert {:ok, _conn, _jwt} = Oli.Lti_1p3.Utils.validate_jwt_signature(conn, id_token, "some-keyset-url")
    end

    test "fails on missing oidc params" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      params = params
        |> Map.drop(["scope", "nonce"])

      assert AuthorizationRedirect.authorize_redirect(params, user) == {:error, %{reason: :invalid_oidc_params, msg: "Invalid OIDC params. The following parameters are missing: nonce, scope", missing_params: ["nonce", "scope"]}}
    end

    test "fails on incorrect oidc scope" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      params = params
        |> Map.put("scope", "invalid_scope")

      assert AuthorizationRedirect.authorize_redirect(params, user) == {:error, %{reason: :invalid_oidc_scope, msg: "Invalid OIDC scope: invalid_scope. Scope must be 'openid'"}}
    end

    test "fails on invalid login_hint user session" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      other_user = user_fixture()

      params = params
        |> Map.put("login_hint", "#{other_user.id}")

      assert AuthorizationRedirect.authorize_redirect(params, user) == {:error, %{reason: :invalid_login_hint, msg: "Login hint must be linked with an active user session"}}
    end

    test "fails on invalid client_id" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      params = params
        |> Map.put("client_id", "some-other-client-id")

      assert AuthorizationRedirect.authorize_redirect(params, user) == {:error, %{reason: :client_not_registered, msg: "No platform exists with client id 'some-other-client-id'"}}
    end

    test "fails on invalid redirect_uri" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      params = params
        |> Map.put("redirect_uri", "some-invalid_redirect-uri")

      assert AuthorizationRedirect.authorize_redirect(params, user) == {:error, %{reason: :unauthorized_redirect_uri, msg: "Redirect URI not authorized in requested context"}}
    end

    test "fails on duplicate nonce" do
      %{
        params: params,
        user: user,
      } = generate_lti_platform_stubs()

      assert {:ok, _target_link_uri, _state, _id_token} = AuthorizationRedirect.authorize_redirect(params, user)

      # try again with the same nonce
      assert {:error, %{reason: :invalid_nonce, msg: "Duplicate nonce"}} == AuthorizationRedirect.authorize_redirect(params, user)
    end
  end

  def generate_lti_platform_stubs(args \\ %{}) do
    user = args[:user] || user_fixture()
    %LoginHint{value: login_hint} = LoginHints.create_login_hint!(user.id)
    %{
      target_link_uri: target_link_uri,
      nonce: nonce,
      client_id: client_id,
      state: state,
      lti_message_hint: lti_message_hint,
      user: user,
    } = %{
      target_link_uri: "some-valid-url",
      nonce: "some-nonce",
      client_id: "some-client-id",
      state: "some-state",
      lti_message_hint: "some-lti-message-hint",
      user: user,
    } |> Map.merge(args)

    {:ok, platform_instance} = PlatformInstances.create_platform_instance(%{
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
      "state" => state,
    }

    # stub conn
    conn = Plug.Test.conn(:post, "/", params)
    conn = Pow.Plug.assign_current_user(conn, user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    %{conn: conn, user: user, state: state, params: params, target_link_uri: target_link_uri, nonce: nonce, client_id: client_id, platform_instance: platform_instance}
  end

end

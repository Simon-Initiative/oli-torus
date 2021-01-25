defmodule Oli.Lti_1p3.AuthorizationRedirectTest do
  use Oli.DataCase

  import Oli.Lti_1p3.TestHelpers
  import Mox

  alias Oli.Lti_1p3.AuthorizationRedirect
  alias Oli.Lti_1p3.MockHTTPoison

  describe "authorize_redirect" do

    test "authorizes a valid redirect request successfully" do
      %{
        conn: conn,
        jwk: jwk,
        state: state,
        params: params,
        target_link_uri: target_link_uri,
      } = generate_lti_platform_stubs()

      # verify authorize_redirect is successful on valid request
      MockHTTPoison
      |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

      assert {:ok, ^target_link_uri, ^state, id_token} = AuthorizationRedirect.authorize_redirect(conn, params)

      # validate the id_token returned is signed correctly
      active_jwk = Oli.Lti_1p3.Utils.get_active_jwk()
      MockHTTPoison
      |> expect(:get, fn _url -> mock_get_jwk_keys(active_jwk) end)

      assert {:ok, _conn, _jwt} = Oli.Lti_1p3.Utils.validate_jwt_signature(conn, id_token, "some-keyset-url")
    end
  end

  def generate_lti_platform_stubs(args \\ %{}) do
    %{
      jwk: jwk,
      target_link_uri: target_link_uri,
      nonce: nonce,
      client_id: client_id,
    } = %{
      jwk: jwk_fixture(),
      target_link_uri: "some-target-link-uri",
      nonce: UUID.uuid4(),
      client_id: "some-client-id",
    } |> Map.merge(args)

    custom_header = %{"kid" => jwk.kid}
    signer = Joken.Signer.create("RS256", %{"pem" => jwk.pem}, custom_header)
    {:ok, claims} = Joken.Config.default_claims(iss: "some-issuer", aud: "oli-platform")
    |> Joken.generate_claims(%{
      "params" => %{
        "action" => "create",
        "client_id" => client_id,
        "controller" => "lti/login_initiations",
        "iss" => "https://dangerous-turtle-47.loca.lt",
        "login_hint" => "some-login-hint",
        "lti_message_hint" => "lti-message-hint",
        "target_link_uri" => target_link_uri,
        "tool_id" => "1234"
      },
      "state_nonce" => nonce,
      "sub" => client_id,
      "tool_id" => 1234
    })

    {:ok, state, _claims} = Joken.encode_and_sign(claims, signer)

    params = %{
      "client_id" => client_id,
      "login_hint" => "some-login-hint",
      "lti_message_hint" => "lti-message-hint",
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

    %{conn: conn, jwk: jwk, state: state, params: params, target_link_uri: target_link_uri, nonce: nonce, client_id: client_id}
  end

end

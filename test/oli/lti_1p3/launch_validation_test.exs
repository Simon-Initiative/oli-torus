defmodule Oli.Lti_1p3.LaunchValidationTest do
  use OliWeb.ConnCase

  alias Oli.TestHelpers
  alias Lti_1p3.MockHTTPoison
  alias Oli.Lti_1p3.LaunchValidation

  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  def mock_get_jwk_keys(jwk) do
    body = Jason.encode!(%{
      keys: [
        jwk.pem
        |> JOSE.JWK.from_pem()
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> (fn {_kty, public_jwk} -> public_jwk end).()
        |> Map.put("typ", jwk.typ)
        |> Map.put("alg", jwk.alg)
        |> Map.put("kid", jwk.kid)
        |> Map.put("use", "sig")
      ]
    })

    {:ok, %HTTPoison.Response{status_code: 200, body: body}}
  end

  describe "launch validation" do
    test "passes validation for a valid launch request" do
      %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs()
      MockHTTPoison
      |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

      assert {:ok, _, _jwt_body} = LaunchValidation.validate(conn)
    end
  end

  test "fails validation on missing oidc state" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: nil, lti_1p3_state: nil})

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_oidc_state, msg: "State from session is missing. Make sure cookies are enabled and configured correctly"}}
  end

  test "fails validation on invalid oidc state" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: "doesn't", lti_1p3_state: "match"})

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_oidc_state, msg: "State from OIDC request does not match session"}}
  end

  test "fails validation if registration doesn't exist for client id" do
    institution = institution_fixture()
    jwk = jwk_fixture()
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs(%{
      kid: "one kid",
      registration_params: %{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        tool_jwk_id: jwk.id,
        institution_id: institution.id,
      },
    })

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_registration, msg: "Registration with issuer \"https://lti-ri.imsglobal.org\" and client id \"12345\" not found", issuer: "https://lti-ri.imsglobal.org", client_id: "12345"}}
  end

  test "fails validation on missing id_token" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: nil})

    assert LaunchValidation.validate(conn) == {:error, %{reason: :missing_param, msg: "Missing id_token"}}
  end

  test "fails validation on malformed id_token" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: "malformed3"})

      assert LaunchValidation.validate(conn) == {:error, %{reason: :token_malformed, msg: "Invalid JWT"}}
  end

  test "fails validation on invalid signature" do
    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs()

    other_jwk = jwk_fixture(%{kid: jwk.kid})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(other_jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :signature_error, msg: "Invalid JWT"}}
  end

  test "fails validation on expired exp" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["exp"], Timex.now |> Timex.subtract(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT exp is expired"}}
  end

  test "fails validation on token iat invalid" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["iat"], Timex.now |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT iat is invalid"}}
  end

  test "fails validation on both expired exp and iat invalid" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["exp"], Timex.now |> Timex.subtract(Timex.Duration.from_minutes(5)) |> Timex.to_unix)
      |> put_in(["iat"], Timex.now |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_jwt_timestamp, msg: "JWT exp and iat are invalid"}}
  end

  test "fails validation on duplicate nonce" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], "duplicate nonce")
    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    # passes on first attempt with a given nonce
    assert {:ok, _, _jwt_body} = LaunchValidation.validate(conn)

    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    # fails on second attempt with a duplicate nonce
    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_nonce, msg: "Duplicate nonce"}}
  end

  test "fails validation if deployment doesn't exist" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/deployment_id"], "invalid_deployment_id")

    %{conn: conn, jwk: jwk, registration: registration} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_deployment, msg: "Deployment with id \"invalid_deployment_id\" not found", registration_id: registration.id, deployment_id: "invalid_deployment_id"}}
  end

  test "fails validation on missing message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], nil)

    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_message_type, msg: "Missing message type"}}
  end

  test "fails validation on invalid message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], "InvalidMessageType")

    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert LaunchValidation.validate(conn) == {:error, %{reason: :invalid_message_type, msg: "Invalid or unsupported message type \"InvalidMessageType\""}}
  end

  test "caches lti launch params" do
    %{conn: conn, jwk: jwk} = TestHelpers.Lti_1p3.generate_lti_stubs()
    MockHTTPoison
    |> expect(:get, fn _url -> mock_get_jwk_keys(jwk) end)

    assert {:ok, conn, _jwt_body} = LaunchValidation.validate(conn)

    assert Map.has_key?(Plug.Conn.get_session(conn), "lti_1p3_sub")
  end

end

defmodule Oli.Lti_1p3.LaunchValidationTest do
  use OliWeb.ConnCase

  alias Oli.TestHelpers
  alias Oli.Lti_1p3.LaunchValidation
  alias Oli.Lti_1p3.KeyGenerator

  describe "launch validation" do
    test "passes validation for a valid launch request" do
      %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs()

      assert {:ok, _, _jwt_body} = LaunchValidation.validate(conn, get_public_key)
    end
  end

  test "fails validation on missing oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: nil, lti_1p3_state: nil})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_oidc_state, msg: "State from session is missing. Make sure cookies are enabled and configured correctly"}}
  end

  test "fails validation on invalid oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: "doesnt", lti_1p3_state: "match"})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_oidc_state, msg: "State from OIDC request does not match session"}}
  end

  test "fails validation if registration does not exist for client id" do
    institution = institution_fixture()
    jwk = jwk_fixture()
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{
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

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_registration, msg: "Registration with issuer \"https://lti-ri.imsglobal.org\" and client id \"12345\" not found", issuer: "https://lti-ri.imsglobal.org", client_id: "12345"}}
  end

  test "fails validation on missing id_token" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: nil})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :missing_id_token, msg: "Missing id_token"}}
  end

  test "fails validation on malformed id_token" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: "malformed3"})

      assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :token_malformed, msg: "Invalid id_token"}}
  end

  test "fails validation on invalid signature" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs()

    get_public_key = fn _registration, _kid ->
      # generate a different public key than the corresponding one used to sign the jwt
      %{public_key: public_key} = KeyGenerator.generate_key_pair()
      {:ok, JOSE.JWK.from_pem(public_key)}
    end

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :signature_error, msg: "Invalid id_token"}}
  end

  test "fails validation on expired exp" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["exp"], Timex.now |> Timex.subtract(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_token_timestamp, msg: "Token exp is expired"}}
  end

  test "fails validation on token iat invalid" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["iat"], Timex.now |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_token_timestamp, msg: "Token iat is invalid"}}
  end

  test "fails validation on both expired exp and iat invalid" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["exp"], Timex.now |> Timex.subtract(Timex.Duration.from_minutes(5)) |> Timex.to_unix)
      |> put_in(["iat"], Timex.now |> Timex.add(Timex.Duration.from_minutes(5)) |> Timex.to_unix)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_token_timestamp, msg: "Token exp and iat are invalid"}}
  end

  test "fails validation on duplicate nonce" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], "duplicate nonce")
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    # passes on first attempt with a given nonce
    assert {:ok, _, _jwt_body} = LaunchValidation.validate(conn, get_public_key)

    # fails on second attempt with a duplicate nonce
    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_nonce, msg: "Duplicate nonce"}}
  end

  test "fails validation if deployement doesnt exist" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/deployment_id"], "invalid_deployment_id")

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_deployment, msg: "Deployment with id \"invalid_deployment_id\" not found", deployment_id: "invalid_deployment_id"}}
  end

  test "fails validation on missing message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], nil)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_message_type, msg: "Missing message type"}}
  end

  test "fails validation on invalid message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], "InvalidMessageType")

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, %{reason: :invalid_message_type, msg: "Invalid or unsupported message type \"InvalidMessageType\""}}
  end

  test "caches lti launch params" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs()

    assert {:ok, conn, _jwt_body} = LaunchValidation.validate(conn, get_public_key)

    assert Map.has_key?(Plug.Conn.get_session(conn), "lti_1p3_sub")
  end

end

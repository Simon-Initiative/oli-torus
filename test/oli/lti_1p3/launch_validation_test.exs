defmodule Oli.Lti_1p3.LaunchValidationTest do
  use OliWeb.ConnCase

  alias Oli.TestHelpers
  alias Oli.Lti_1p3.LaunchValidation
  alias Oli.Lti_1p3.KeyGenerator

  describe "launch validation" do
    test "passes validation for a valid launch request" do
      %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs()

      assert {:ok, conn} = LaunchValidation.validate(conn, get_public_key)
    end
  end

  test "fails validation on missing oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: nil, lti1p3_state: nil})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "State from OIDC request is missing"}
  end

  test "fails validation on invalid oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: "doesnt", lti1p3_state: "match"})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "State from OIDC request does not match"}
  end

  test "fails validation if registration doesnt exist for kid" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{
      kid: "one kid",
      registration_params: %{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        tool_private_key: "some tool_private_key",
        kid: "different kid",
      },
    })

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Registration with kid \"one kid\" not found"}
  end

  test "fails validation on missing id_token" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: nil})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Missing id_token"}
  end

  test "fails validation on malformed id_token" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{id_token: "malformed3"})

      assert LaunchValidation.validate(conn, get_public_key) == {:error, :token_malformed}
  end

  test "fails validation on invalid signature" do
    %{conn: conn} = TestHelpers.Lti_1p3.generate_lti_stubs()

    get_public_key = fn _registration, _kid ->
      # generate a different public key than the corresponding one used to sign the jwt
      %{public_key: public_key} = KeyGenerator.generate_key_pair()
      {:ok, JOSE.JWK.from_pem(public_key)}
    end

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Invalid signature on id_token"}
  end

  test "fails validation on duplicate nonce" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{kid: "one", nonce: "duplicate nonce"})

    # passes on first attempt with a given nonce
    assert {:ok, conn} = LaunchValidation.validate(conn, get_public_key)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{kid: "two", nonce: "duplicate nonce"})

    # fails on second attempt with a duplicate nonce
    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Duplicate nonce"}
  end

  test "fails validation if deployement doesnt exist" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/deployment_id"], "invalid_deployment_id")

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Deployment with id \"invalid_deployment_id\" not found"}
  end

  test "fails validation on missing message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], nil)

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Missing message type"}
  end

  test "fails validation on invalid message type" do
    claims = TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["nonce"], UUID.uuid4())
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/message_type"], "InvalidMessageType")

    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{claims: claims})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "Invalid or unsupported message type \"InvalidMessageType\""}
  end

  test "caches lti launch params" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs()

    assert {:ok, conn} = LaunchValidation.validate(conn, get_public_key)

    assert Map.has_key?(Plug.Conn.get_session(conn), "lti1p3_launch_params")
  end

end

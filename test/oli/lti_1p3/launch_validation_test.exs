defmodule Oli.Lti_1p3.LaunchValidationTest do
  use OliWeb.ConnCase

  alias Oli.TestHelpers
  alias Oli.Lti_1p3.LaunchValidation

  describe "launch validation" do
    test "returns {:ok} for a valid launch request" do
      %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs()

      assert LaunchValidation.validate(conn, get_public_key) == {:ok}
    end
  end

  test "fails on missing oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: nil, lti1p3_state: nil})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "State from OIDC request is missing"}
  end

  test "fails on invalid oidc state" do
    %{conn: conn, get_public_key: get_public_key} = TestHelpers.Lti_1p3.generate_lti_stubs(%{state: "doesnt", lti1p3_state: "match"})

    assert LaunchValidation.validate(conn, get_public_key) == {:error, "State from OIDC request does not match"}
  end

end

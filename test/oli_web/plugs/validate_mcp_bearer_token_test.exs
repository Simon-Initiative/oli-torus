defmodule OliWeb.Plugs.ValidateMCPBearerTokenTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Plugs.ValidateMCPBearerToken

  describe "ValidateMCPBearerToken" do
    test "halts connection with 401 when no authorization header is present" do
      conn = build_conn()

      result = ValidateMCPBearerToken.call(conn, nil)

      assert result.halted
      assert result.status == 401
    end

    test "halts connection with 401 when authorization header is malformed" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic invalid")

      result = ValidateMCPBearerToken.call(conn, nil)

      assert result.halted
      assert result.status == 401
    end

    test "halts connection with 401 when Bearer token is invalid" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_token")

      result = ValidateMCPBearerToken.call(conn, nil)

      assert result.halted
      assert result.status == 401
    end

    test "init returns nil" do
      assert ValidateMCPBearerToken.init(nil) == nil
    end
  end
end

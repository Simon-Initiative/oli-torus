defmodule OliWeb.Common.LtiSessionTest do
  use OliWeb.ConnCase

  alias OliWeb.Common.LtiSession

  describe "lti session" do
    setup [:setup_session]

    test "should put the lti params key for a particular user in the lti session", %{conn: conn} do
      conn = LtiSession.put_session_lti_params(conn, 12345)

      assert Plug.Conn.get_session(conn, :lti_params_id) == 12345
    end

    test "should get the lti params key for the latest user in the lti session", %{conn: conn} do
      conn = LtiSession.put_session_lti_params(conn, 12345)

      assert LtiSession.get_session_lti_params(conn) == 12345
    end
  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    %{conn: conn}
  end
end

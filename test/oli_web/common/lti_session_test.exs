defmodule OliWeb.Common.LtiSessionTest do
  use OliWeb.ConnCase

  alias OliWeb.Common.LtiSession

  describe "lti session" do
    setup [:setup_session]

    test "should put the lti params key for a particular user in the lti session", %{conn: conn} do
      conn = LtiSession.put_user_params(conn, "some-cache-key")

      assert Plug.Conn.get_session(conn, :lti_session) == %{
        user_params: "some-cache-key"
      }
    end

    test "should put the lti params key for a particular user's section in the lti session", %{conn: conn} do
      conn = LtiSession.put_section_params(conn, "some-section-slug", "some-cache-key")

      assert Plug.Conn.get_session(conn, :lti_session) == %{
        sections: %{
          "some-section-slug" => "some-cache-key"
        }
      }
    end

    test "should get the lti params key for the latest user in the lti session", %{conn: conn} do
      conn = LtiSession.put_user_params(conn, "some-cache-key")

      assert LtiSession.get_user_params(conn) == "some-cache-key"
    end

    test "should get the lti params key for a particular platform and user's section in the lti session", %{conn: conn} do
      conn = LtiSession.put_section_params(conn, "some-section-slug", "some-cache-key")

      assert LtiSession.get_section_params(conn, "some-section-slug") == "some-cache-key"
    end

  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    conn = Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    %{conn: conn}
  end

end

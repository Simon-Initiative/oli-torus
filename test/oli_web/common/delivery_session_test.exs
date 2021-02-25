defmodule OliWeb.Common.DeliverySessionTest do
  use OliWeb.ConnCase

  alias OliWeb.Common.DeliverySession

  describe "delivery session" do
    setup [:setup_session]

    test "should put the user_id for a particular platform in the delivery session", %{conn: conn} do
      conn = DeliverySession.put_user(conn, "some-platform-id", "some-user-id")

      assert Plug.Conn.get_session(conn, :delivery) == %{
        "some-platform-id" => %{
          user_id: "some-user-id",
        }
      }
    end

    test "should put the lti params key for a particular user's section in the delivery session", %{conn: conn} do
      conn = DeliverySession.put_user_section_lti_params_key(conn, "some-platform-id", "some-section-slug", "some-cache-key")

      assert Plug.Conn.get_session(conn, :delivery) == %{
        "some-platform-id" => %{
          sections: %{
            "some-section-slug" => "some-cache-key",
          }
        }
      }
    end

    test "should get the user_id and lti params key for a particular platform and user's section in the delivery session", %{conn: conn} do
      conn = conn
        |> DeliverySession.put_user("some-platform-id", "some-user-id")
        |> DeliverySession.put_user_section_lti_params_key("some-platform-id", "some-section-slug", "some-cache-key")

      assert DeliverySession.get_user(conn, "some-platform-id") == "some-user-id"
      assert DeliverySession.get_user_section_lti_params_key(conn, "some-platform-id", "some-section-slug") == "some-cache-key"
    end

  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    conn = Plug.Test.init_test_session(conn, delivery: nil)
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    %{conn: conn}
  end

end

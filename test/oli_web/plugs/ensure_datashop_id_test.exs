defmodule OliWeb.Plugs.EnsureDatashopIdTest do
  use OliWeb.ConnCase

  alias OliWeb.Plugs.EnsureDatashopId

  @opts []

  describe "ensure datashop id plug" do
    test "assigns a new datashop_session_id if not present in session", %{conn: conn} do
      conn =
        Plug.Test.init_test_session(conn, %{})

      conn = EnsureDatashopId.call(conn, @opts)

      assert get_session(conn, :datashop_session_id) != nil
      assert conn.assigns[:datashop_session_id] == get_session(conn, :datashop_session_id)
    end

    test "uses existing datashop_session_id if present in session", %{conn: conn} do
      existing_id = "existing-session-id"

      conn =
        Plug.Test.init_test_session(conn, %{datashop_session_id: existing_id})

      conn = EnsureDatashopId.call(conn, @opts)

      assert get_session(conn, :datashop_session_id) == existing_id
      assert conn.assigns[:datashop_session_id] == existing_id
    end
  end
end

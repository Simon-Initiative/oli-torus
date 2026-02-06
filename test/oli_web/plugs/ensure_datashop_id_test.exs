defmodule OliWeb.Plugs.EnsureDatashopIdTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Plugs.EnsureDatashopId

  @opts []

  describe "ensure datashop id plug" do
    test "create a new datashop_session_id if not present in session", %{conn: conn} do
      conn =
        Plug.Test.init_test_session(conn, %{})

      conn = EnsureDatashopId.call(conn, @opts)

      assert get_session(conn, :datashop_session_id) != nil
      assert get_session(conn, :datashop_session_updated_at) != nil

      assert conn.assigns[:datashop_session_id] == get_session(conn, :datashop_session_id)
    end

    test "create a new datashop_session_id if present in session but a timestamp is not", %{
      conn: conn
    } do
      # session id
      existing_session_id = "existing-session-id"

      conn =
        Plug.Test.init_test_session(conn, %{datashop_session_id: existing_session_id})

      conn = EnsureDatashopId.call(conn, @opts)

      assert existing_session_id != get_session(conn, :datashop_session_id)
      assert get_session(conn, :datashop_session_updated_at) != nil
    end

    test "updates timestamp on existing datashop_session_id if present in session", %{conn: conn} do
      # lifetime is 30 minutes
      existing_session_id = "existing-session-id"
      original_timestamp = System.os_time(:second) - 29 * 60

      conn =
        Plug.Test.init_test_session(conn, %{
          datashop_session_id: existing_session_id,
          datashop_session_updated_at: original_timestamp
        })

      conn = EnsureDatashopId.call(conn, @opts)

      assert existing_session_id == get_session(conn, :datashop_session_id)

      assert get_session(conn, :datashop_session_updated_at) > original_timestamp
    end

    test "create new datashop session id if session is older than the configured session lifetime",
         %{conn: conn} do
      # lifetime is 30 minutes
      existing_session_id = "existing-session-id"
      expired_timestamp = System.os_time(:second) - 31 * 60

      conn =
        Plug.Test.init_test_session(conn, %{
          datashop_session_id: existing_session_id,
          datashop_session_updated_at: expired_timestamp
        })

      conn = EnsureDatashopId.call(conn, @opts)

      assert existing_session_id != get_session(conn, :datashop_session_id)

      assert get_session(conn, :datashop_session_updated_at) > expired_timestamp
    end

    test "create new datashop session id if legacy tuple timestamp is present", %{conn: conn} do
      existing_session_id = "existing-session-id"
      legacy_timestamp = {23, 59, 0}

      conn =
        Plug.Test.init_test_session(conn, %{
          datashop_session_id: existing_session_id,
          datashop_session_updated_at: legacy_timestamp
        })

      conn = EnsureDatashopId.call(conn, @opts)

      assert existing_session_id != get_session(conn, :datashop_session_id)
      assert is_integer(get_session(conn, :datashop_session_updated_at))
    end
  end
end

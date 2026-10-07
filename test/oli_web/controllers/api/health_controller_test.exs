defmodule OliWeb.HealthControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint OliWeb.Endpoint

  setup do
    Oli.Health.starting()

    on_exit(fn ->
      Oli.Health.starting()
      Oli.Health.started()
    end)
  end

  test "unauthenticated startup returns only starting with no cache or redirect" do
    conn = get(build_conn(), "/healthz")
    assert json_response(conn, 503) == %{"status" => "starting"}
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert get_resp_header(conn, "location") == []
    assert conn.private[:plug_session_fetch] != :done
  end

  test "running and draining liveness need no database checkout or external calls" do
    # No sandbox checkout: a database call would fail this request.
    Oli.Health.started()

    for transition <- [fn -> :ok end, &Oli.Release.drain/0] do
      transition.()

      for scheme <- [:http, :https] do
        conn = get(%{build_conn() | scheme: scheme}, "/healthz")
        assert json_response(conn, 200) == %{"status" => "Ayup!"}
        assert get_resp_header(conn, "cache-control") == ["no-store"]
      end
    end
  end
end

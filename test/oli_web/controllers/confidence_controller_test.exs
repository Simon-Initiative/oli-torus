defmodule OliWeb.ConfidenceControllerTest do
  use OliWeb.ConnCase

  test "serves the interactive explorer to an admin", %{conn: conn} do
    {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})
    conn = get(conn, ~p"/admin/confidence.html")
    html = html_response(conn, 200)

    assert html =~ "Confidence, shaped by evidence."
    assert html =~ ~s(id="midpoint" type="range" min="2" max="15")
    assert html =~ ~s(id="steepness" type="range" min="2" max="8")
    assert html =~ "function confidence(n, m, s)"
    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "redirects unauthenticated visitors to author login", %{conn: conn} do
    conn = get(conn, ~p"/admin/confidence.html")
    assert redirected_to(conn) == ~p"/authors/log_in"
  end

  test "rejects authenticated authors without an admin role", %{conn: conn} do
    {:ok, conn: conn, author: _author} = author_conn(%{conn: conn})
    conn = get(conn, ~p"/admin/confidence.html")

    assert redirected_to(conn) == ~p"/workspaces/course_author"
    refute conn.resp_body =~ "function confidence(n, m, s)"
  end
end

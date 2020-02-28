defmodule OliWeb.PageControllerTest do
  use OliWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to OLI Authoring!"
  end
end

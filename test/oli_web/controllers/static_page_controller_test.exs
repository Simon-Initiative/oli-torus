defmodule OliWeb.StaticPageControllerTest do
  use OliWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")

    assert html_response(conn, 200) =~ "Welcome to"
    assert html_response(conn, 200) =~ "Learner/Educator Sign In"
    assert html_response(conn, 200) =~ "Authoring Sign In"
  end

  describe "set_session" do
    test "stores the message id correctly when the session value is not set", %{conn: conn} do
      conn = post(conn, Routes.static_page_path(conn, :set_session), dismissed_message: "1")

      assert get_session(conn, :dismissed_messages) == [1]
    end

    test "stores the message id correctly when the session value is not empty", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{dismissed_messages: [2]})

      conn = post(conn, Routes.static_page_path(conn, :set_session), dismissed_message: "1")

      assert get_session(conn, :dismissed_messages) == [1, 2]
    end
  end
end

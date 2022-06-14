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

  describe "local timezone" do
    test "loads timezone script when local timezone is not set", %{conn: conn} do
      conn = get(conn, "/")

      assert html_response(conn, 200) =~ "/js/timezone.js"
    end

    test "does not load timezone script when local timezone is set", context do
      {:ok, conn: conn} = set_timezone(context)

      conn = get(conn, "/")

      refute html_response(conn, 200) =~ "/js/timezone.js"
    end
  end

  describe "keep alive" do
    test "redirects when user is not logged in", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :keep_alive))

      assert html_response(conn, 302)
        =~ "You are being <a href=\"/session/new?request_path=%2Fkeep-alive\">redirected"
    end

    test "returns ok when user is logged in", conn do
      {:ok, conn: conn, user: _} = user_conn(conn)
      conn = get(conn, Routes.static_page_path(conn, :keep_alive))

      assert response(conn, 200) =~ "Ok"
    end

    test "redirects when author is not logged in", %{conn: conn} do
      conn = get(conn, Routes.author_keep_alive_path(conn, :keep_alive))

      assert html_response(conn, 302)
        =~ "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fkeep-alive\">redirected"
    end

    test "returns ok when author is logged in", conn do
      {:ok, conn: conn, author: _} = author_conn(conn)
      conn = get(conn, Routes.author_keep_alive_path(conn, :keep_alive))

      assert response(conn, 200) =~ "Ok"
    end
  end
end

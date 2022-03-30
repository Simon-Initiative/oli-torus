defmodule OliWeb.SessionControllerTest do
  use OliWeb.ConnCase

  describe "signout" do
    setup [:setup_session_data]

    test "signs out user and clears session data when logged in as an instructor", context do
      {:ok, conn: conn, user: _} = user_conn(context)

      conn = delete(conn, Routes.session_path(conn, :signout, type: :user))

      refute conn.assigns.current_user
      refute conn.private.plug_session["current_user_id"]
      refute conn.private.plug_session["dismissed_messages"]
      assert redirected_to(conn, 302) == Routes.static_page_path(conn, :index)
    end

    test "signs out user and clears session data when logged in as an author", context do
      {:ok, conn: conn, author: _} = author_conn(context)

      conn = delete(conn, Routes.authoring_session_path(conn, :signout, type: :author))

      refute conn.assigns.current_author
      refute conn.private.plug_session["current_author_id"]
      refute conn.private.plug_session["dismissed_messages"]
      assert redirected_to(conn, 302) == Routes.static_page_path(conn, :index)
    end

    defp setup_session_data(%{conn: conn}) do
      conn = Plug.Test.init_test_session(conn, %{dismissed_messages: [1]})

      {:ok, conn: conn}
    end
  end
end

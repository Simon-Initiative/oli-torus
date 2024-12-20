defmodule OliWeb.AuthorAuthTest do
  use OliWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Oli.Accounts
  alias OliWeb.AuthorAuth

  @remember_me_cookie "_oli_web_author_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{author: Oli.Utils.Seeder.AccountsFixtures.author_fixture(), conn: conn}
  end

  describe "log_in_author/3" do
    test "stores the author token in the session", %{conn: conn, author: author} do
      conn = AuthorAuth.log_in_author(conn, author)
      assert token = get_session(conn, :author_token)

      assert get_session(conn, :author_live_socket_id) ==
               "authors_sessions:#{Base.url_encode64(token)}"

      assert redirected_to(conn) == ~p"/workspaces/course_author"
      assert Accounts.get_author_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, author: author} do
      conn = conn |> put_session(:to_be_removed, "value") |> AuthorAuth.log_in_author(author)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, author: author} do
      conn = conn |> put_session(:author_return_to, "/hello") |> AuthorAuth.log_in_author(author)
      assert redirected_to(conn) == "/hello"
    end
  end

  describe "logout_author/1" do
    test "erases session and cookies", %{conn: conn, author: author} do
      author_token = Accounts.generate_author_session_token(author)

      conn =
        conn
        |> put_session(:author_token, author_token)
        |> put_req_cookie(@remember_me_cookie, author_token)
        |> fetch_cookies()
        |> AuthorAuth.log_out_author()

      refute get_session(conn, :author_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/authors/log_in"
      refute Accounts.get_author_by_session_token(author_token)
    end

    test "broadcasts to the given author_live_socket_id", %{conn: conn} do
      author_live_socket_id = "authors_sessions:abcdef-token"
      OliWeb.Endpoint.subscribe(author_live_socket_id)

      conn
      |> put_session(:author_live_socket_id, author_live_socket_id)
      |> AuthorAuth.log_out_author()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^author_live_socket_id}
    end

    test "works even if author is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> AuthorAuth.log_out_author()
      refute get_session(conn, :author_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/authors/log_in"
    end
  end

  describe "fetch_current_author/2" do
    test "authenticates author from session", %{conn: conn, author: author} do
      author_token = Accounts.generate_author_session_token(author)

      conn =
        conn |> put_session(:author_token, author_token) |> AuthorAuth.fetch_current_author([])

      assert conn.assigns.current_author.id == author.id
    end

    test "authenticates author from cookies", %{conn: conn, author: author} do
      logged_in_conn =
        conn |> fetch_cookies() |> AuthorAuth.log_in_author(author, %{"remember_me" => "true"})

      author_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> AuthorAuth.fetch_current_author([])

      assert conn.assigns.current_author.id == author.id
      assert get_session(conn, :author_token) == author_token

      assert get_session(conn, :author_live_socket_id) ==
               "authors_sessions:#{Base.url_encode64(author_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, author: author} do
      _ = Accounts.generate_author_session_token(author)
      conn = AuthorAuth.fetch_current_author(conn, [])
      refute get_session(conn, :author_token)
      refute conn.assigns.current_author
    end
  end

  describe "on_mount: mount_current_author" do
    test "assigns current_author based on a valid author_token", %{conn: conn, author: author} do
      author_token = Accounts.generate_author_session_token(author)
      session = conn |> put_session(:author_token, author_token) |> get_session()

      {:cont, updated_socket} =
        AuthorAuth.on_mount(:mount_current_author, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_author.id == author.id
    end

    test "assigns nil to current_author assign if there isn't a valid author_token", %{conn: conn} do
      author_token = "invalid_token"
      session = conn |> put_session(:author_token, author_token) |> get_session()

      {:cont, updated_socket} =
        AuthorAuth.on_mount(:mount_current_author, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_author == nil
    end

    test "assigns nil to current_author assign if there isn't a author_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        AuthorAuth.on_mount(:mount_current_author, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_author == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_author based on a valid author_token", %{
      conn: conn,
      author: author
    } do
      author_token = Accounts.generate_author_session_token(author)
      session = conn |> put_session(:author_token, author_token) |> get_session()

      {:cont, updated_socket} =
        AuthorAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_author.id == author.id
    end

    test "redirects to login page if there isn't a valid author_token", %{conn: conn} do
      author_token = "invalid_token"
      session = conn |> put_session(:author_token, author_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = AuthorAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_author == nil
    end

    test "redirects to login page if there isn't a author_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: OliWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = AuthorAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_author == nil
    end
  end

  describe "on_mount: :redirect_if_author_is_authenticated" do
    test "redirects if there is an authenticated  author ", %{conn: conn, author: author} do
      author_token = Accounts.generate_author_session_token(author)
      session = conn |> put_session(:author_token, author_token) |> get_session()

      assert {:halt, _updated_socket} =
               AuthorAuth.on_mount(
                 :redirect_if_author_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated author", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               AuthorAuth.on_mount(
                 :redirect_if_author_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_author_is_authenticated/2" do
    test "redirects if author is authenticated", %{conn: conn, author: author} do
      conn =
        conn
        |> assign(:current_author, author)
        |> AuthorAuth.redirect_if_author_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/workspaces/course_author"
    end

    test "does not redirect if author is not authenticated", %{conn: conn} do
      conn = AuthorAuth.redirect_if_author_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_author/2" do
    test "redirects if author is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> AuthorAuth.require_authenticated_author([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/authors/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> AuthorAuth.require_authenticated_author([])

      assert halted_conn.halted
      assert get_session(halted_conn, :author_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> AuthorAuth.require_authenticated_author([])

      assert halted_conn.halted
      assert get_session(halted_conn, :author_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> AuthorAuth.require_authenticated_author([])

      assert halted_conn.halted
      refute get_session(halted_conn, :author_return_to)
    end

    test "does not redirect if author is authenticated", %{conn: conn, author: author} do
      conn =
        conn |> assign(:current_author, author) |> AuthorAuth.require_authenticated_author([])

      refute conn.halted
      refute conn.status
    end
  end
end

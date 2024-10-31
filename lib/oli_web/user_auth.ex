defmodule OliWeb.UserAuth do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Accounts
  alias OliWeb.AuthorAuth

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_oli_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:user_live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    user_return_to =
      params["request_path"] || get_session(conn, :user_return_to) || signed_in_path(conn)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    # A lot of existing liveviews depends on the current_user_id being in the session.
    # We eventually want to remove this, but for now, we will add it to appease the existing code.
    |> put_user_id_in_session(user.id)
    |> create_datashop_session_id()
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    # when clearing the session, we want to preserve the following keys
    # so that the renew doesn't affect an author's session or other data
    # unrelated to the user session.
    preserve_session_data =
      get_session(conn)
      |> Map.take([
        "browser_timezone",
        "author_token",
        "author_live_socket_id",
        "current_author_id"
      ])

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> restore_preserved_session_data(preserve_session_data)
  end

  defp restore_preserved_session_data(conn, data) do
    Enum.reduce(data, conn, fn {key, value}, conn ->
      put_session(conn, key, value)
    end)
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if user_live_socket_id = get_session(conn, :user_live_socket_id) do
      OliWeb.Endpoint.broadcast(user_live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    conn
    |> assign(:current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule OliWeb.PageLive do
        use OliWeb, :live_view

        on_mount {OliWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{OliWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user || socket.assigns.is_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    # Note: When a user first accesses an application using LiveView, the LiveView is first rendered
    # in its disconnected state, as part of a regular HTML response. By using assign_new in the
    # mount callback of your LiveView, you can instruct LiveView to re-use any assigns already set
    # in conn during disconnected state.
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
    |> preload_platform_roles()
    |> preload_linked_author()
    |> assign_datashop_session_id(session)
    |> AuthorAuth.mount_current_author(session)
  end

  defp preload_platform_roles(socket) do
    case socket.assigns.current_user do
      nil ->
        socket

      user ->
        Phoenix.Component.assign(socket, :current_user, Accounts.preload_platform_roles(user))
    end
  end

  defp preload_linked_author(socket) do
    case socket.assigns.current_user do
      nil ->
        socket

      %Accounts.User{} = user ->
        Phoenix.Component.assign(socket, :current_user, Accounts.preload_linked_author(user))
    end
  end

  defp assign_datashop_session_id(socket, session) do
    Phoenix.Component.assign_new(socket, :datashop_session_id, fn ->
      if datashop_session_id = session["datashop_session_id"] do
        datashop_session_id
      else
        nil
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    # This block assumes that any admin authoring account that may be logged in has already been
    # loaded into the assigns by the AuthorAuth module. This should be the case since both
    # :fetch_current_author and :fetch_current_user are called in that exact order in the router
    # base :browser and :api pipelines.
    if conn.assigns[:current_user] || conn.assigns[:is_admin] do
      conn
      |> require_confirmed_email()
      |> check_account_lock()
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  defp require_confirmed_email(conn) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      %Accounts.User{independent_learner: true, email_confirmed_at: nil} ->
        conn
        |> renew_session()
        |> delete_resp_cookie(@remember_me_cookie)
        |> put_flash(:info, "You must confirm your email to continue.")
        |> redirect(to: ~p"/users/confirm")
        |> halt()

      _ ->
        conn
    end
  end

  defp check_account_lock(conn) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      %Accounts.User{locked_at: nil} ->
        conn

      _ ->
        conn
        |> renew_session()
        |> delete_resp_cookie(@remember_me_cookie)
        |> put_flash(
          :error,
          "Your account has been locked. Please contact support for assistance."
        )
        |> redirect(to: ~p"/users/log_in")
        |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:user_live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp put_user_id_in_session(conn, user_id) do
    conn
    |> put_session(:current_user_id, user_id)
  end

  defp create_datashop_session_id(conn) do
    conn
    |> put_session(:datashop_session_id, UUID.uuid4())
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/workspaces/student"
end

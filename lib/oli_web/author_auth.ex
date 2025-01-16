defmodule OliWeb.AuthorAuth do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}

  require Logger

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in AuthorToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_oli_web_author_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the author in.
  """
  def log_in_author(conn, author, params \\ %{}) do
    token = Accounts.generate_author_session_token(author)

    conn = maybe_link_user_author_account(conn, author)

    author_return_to =
      params["request_path"] || get_session(conn, :author_return_to) || signed_in_path(conn)

    conn
    |> create_session(author)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: author_return_to)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  @doc """
  Creates a new session for the author.

  This is a lower-level function that is used by log_in_author and
  other LTI/OIDC authorization functions to create a new session for
  the author.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:author_live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def create_session(conn, author) do
    token = Accounts.generate_author_session_token(author)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    # A lot of existing liveviews depends on the current_author_id being in the session.
    # We eventually want to remove this, but for now, we will add it to appease the existing code.
    |> put_author_id_in_session(author.id)
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
    # so that the renew doesn't affect an user's session or other data
    # unrelated to the author session.
    preserve_session_data =
      get_session(conn)
      |> Map.take([
        "browser_timezone",
        "user_token",
        "user_live_socket_id",
        "current_user_id",
        "datashop_session_id",
        "link_account_user_id"
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
  Logs the author out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_author(conn, params \\ %{}) do
    author_token = get_session(conn, :author_token)
    author_token && Accounts.delete_author_session_token(author_token)

    if author_live_socket_id = get_session(conn, :author_live_socket_id) do
      OliWeb.Endpoint.broadcast(author_live_socket_id, "disconnect", %{})
    end

    redirect_to =
      params["request_path"] || ~p"/authors/log_in"

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: redirect_to)
  end

  @doc """
  Authenticates the author by looking into the session
  and remember me token.
  """
  def fetch_current_author(conn, _opts) do
    {author_token, conn} = ensure_author_token(conn)
    author = author_token && Accounts.get_author_by_session_token(author_token)

    conn
    |> assign(:current_author, author)
    |> assign(:is_admin, Accounts.is_admin?(author))
  end

  defp ensure_author_token(conn) do
    if token = get_session(conn, :author_token) do
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
  Handles mounting and authenticating the current_author in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_author` - Assigns current_author
      to socket assigns based on author_token, or nil if
      there's no author_token or no matching author.

    * `:ensure_authenticated` - Authenticates the author from the session,
      and assigns the current_author to socket assigns based
      on author_token.
      Redirects to login page if there's no logged author.

    * `:redirect_if_author_is_authenticated` - Authenticates the author from the session.
      Redirects to signed_in_path if there's a logged author.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_author:

      defmodule OliWeb.PageLive do
        use OliWeb, :live_view

        on_mount {OliWeb.AuthorAuth, :mount_current_author}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{OliWeb.AuthorAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_author, _params, session, socket) do
    {:cont, mount_current_author(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_author(socket, session)

    if socket.assigns.current_author do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/authors/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_author_is_authenticated, _params, session, socket) do
    socket = mount_current_author(socket, session)

    if socket.assigns.current_author do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def mount_current_author(socket, session) do
    socket
    |> Phoenix.Component.assign_new(:current_author, fn ->
      if author_token = session["author_token"] do
        Accounts.get_author_by_session_token(author_token)
      end
    end)
    |> maybe_is_admin()
  end

  defp maybe_is_admin(socket) do
    if author = socket.assigns[:current_author] do
      Phoenix.Component.assign(socket, is_admin: Accounts.is_admin?(author))
    else
      Phoenix.Component.assign(socket, is_admin: false)
    end
  end

  @doc """
  Used for routes that require the author to not be authenticated.
  """
  def redirect_if_author_is_authenticated(conn, _opts) do
    if conn.assigns[:current_author] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the author to be authenticated.

  If you want to enforce the author email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_author(conn, _opts) do
    if conn.assigns[:current_author] do
      conn
      |> require_confirmed_email()
      |> check_account_lock()
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/authors/log_in")
      |> halt()
    end
  end

  defp require_confirmed_email(conn) do
    case conn.assigns[:current_author] do
      nil ->
        conn

      %Accounts.Author{email_confirmed_at: nil} ->
        conn
        |> renew_session()
        |> delete_resp_cookie(@remember_me_cookie)
        |> put_flash(:info, "You must confirm your email to continue.")
        |> redirect(to: ~p"/authors/confirm")
        |> halt()

      _ ->
        conn
    end
  end

  defp check_account_lock(conn) do
    case conn.assigns[:current_author] do
      nil ->
        conn

      %Accounts.Author{locked_at: nil} ->
        conn

      _ ->
        conn
        |> renew_session()
        |> delete_resp_cookie(@remember_me_cookie)
        |> put_flash(
          :error,
          "Your account has been locked. Please contact support for assistance."
        )
        |> redirect(to: ~p"/authors/log_in")
        |> halt()
    end
  end

  def require_admin(conn, _opts) do
    if Accounts.is_admin?(conn.assigns[:current_author]) do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: ~p"/workspaces/course_author")
      |> halt()
    end
  end

  def require_account_admin(conn, _opts) do
    if Accounts.has_admin_role?(conn.assigns[:current_author], :account_admin) do
      conn
    else
      conn
      |> put_flash(:error, "You must be an account admin to access this page.")
      |> redirect(to: ~p"/workspaces/course_author")
      |> halt()
    end
  end

  def require_content_admin(conn, _opts) do
    if Accounts.has_admin_role?(conn.assigns[:current_author], :content_admin) do
      conn
    else
      conn
      |> put_flash(:error, "You must be a content admin to access this page.")
      |> redirect(to: ~p"/workspaces/course_author")
      |> halt()
    end
  end

  def require_system_admin(conn, _opts) do
    if Accounts.has_admin_role?(conn.assigns[:current_author], :system_admin) do
      conn
    else
      conn
      |> put_flash(:error, "You must be a system admin to access this page.")
      |> redirect(to: ~p"/workspaces/course_author")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:author_token, token)
    |> put_session(:author_live_socket_id, "authors_sessions:#{Base.url_encode64(token)}")
  end

  defp put_author_id_in_session(conn, author_id) do
    conn
    |> put_session(:current_author_id, author_id)
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :author_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/workspaces/course_author"

  @doc """
  Stores the link_account_user_id (if specified) of the user account to link an
  author account to after subsequent successful login.
  """
  def maybe_store_link_account_user_id(conn, %{"link_account_user_id" => link_account_user_id}) do
    # Do some validation to ensure the user_id is a valid integer and that
    # the user_id is the same as the current_user_id
    with {user_id, ""} <- Integer.parse(link_account_user_id),
         %User{id: current_user_id} <- conn.assigns[:current_user],
         true <- current_user_id == user_id do
      conn
      |> put_session(:link_account_user_id, user_id)
    else
      e ->
        Logger.error("Error storing link_account_user_id: #{inspect(e)}")

        conn
    end
  end

  def maybe_store_link_account_user_id(conn, _params), do: conn

  @doc """
  Links the author account to the user account if specified in the session after successful login.
  """
  def maybe_link_user_author_account(conn, %Author{} = author) do
    if link_account_user_id = get_session(conn, :link_account_user_id) do
      # ensure the user being linked to is logged in
      case conn.assigns do
        %{current_user: user = %User{id: current_user_id}}
        when current_user_id == link_account_user_id ->
          case Accounts.link_user_author_account(user, author) do
            {:ok, _} ->
              conn
              |> delete_session(:link_account_user_id)
              # replace the author_return_to with the user settings page
              |> put_session(:author_return_to, ~p"/users/settings")
              |> put_flash(
                :info,
                "Your authoring account has been linked to your user account."
              )

            {:error, _} ->
              conn
              |> delete_session(:link_account_user_id)
              |> delete_session(:author_return_to)
              |> put_flash(:error, "Something went wrong. Please try again or contact support.")
              |> redirect(to: ~p"/users/settings")
              |> halt()
          end

        _ ->
          conn
          |> delete_session(:link_account_user_id)
          |> delete_session(:author_return_to)
          |> put_flash(:error, "You must be logged in as a user to link your authoring account.")
          |> redirect(to: ~p"/users/log_in")
          |> halt()
      end
    else
      conn
    end
  end

  def maybe_link_user_author_account(conn, _), do: conn
end

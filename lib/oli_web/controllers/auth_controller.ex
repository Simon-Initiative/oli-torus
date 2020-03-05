defmodule OliWeb.AuthController do
  use OliWeb, :controller
  plug Ueberauth

  alias Oli.Accounts
  alias Oli.Accounts.User

  alias Ueberauth.Strategy.Helpers

  def signin(conn, _params) do
    render(conn, "signin.html")
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def register(conn, _params) do
    render(conn, "register.html")
  end

  def register_email_form(conn, _params) do
    render(conn, "register_email.html", callback_url: Helpers.callback_url(conn))
  end

  def register_email_submit(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      provider: "identity",
      token: auth.credentials.token
    }

    changeset = User.changeset(%User{}, user_params)

    case Accounts.create_user(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Thank you for registering!")
        |> put_session(:user_id, user.id)
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error creating user")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      provider: "google",
      token: auth.credentials.token
    }

    changeset = User.changeset(%User{}, user_params)

    case Accounts.insert_or_update_user(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Thank you for signing in!")
        |> put_session(:user_id, user.id)
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error siging in")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do

    IO.inspect(auth, label: "auth")

    case validate_password(auth.credentials) do
      { :ok } ->
        user = %{id: auth.uid, name: name_from_auth(auth), avatar: auth.info.image}
        # user = %{
        #   email: auth.info.email,
        #   first_name: auth.info.first_name,
        #   last_name: auth.info.last_name,
        #   provider: "google"
        #   token: auth.credentials.token,
        # }
        conn
        |> put_flash(:info, "Successfully authenticated.")
        |> put_session(:current_user, user)
        |> redirect(to: "/")
      { :error, reason } ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: "/")
    end
  end

  def validate_password(credentials) do
    { :ok }
  end

  def name_from_auth(auth) do
    "Some Name"
  end

end

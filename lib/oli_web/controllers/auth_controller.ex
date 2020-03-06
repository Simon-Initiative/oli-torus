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
    render(conn, "register_email.html", validation_errors: %{})
  end

  def register_email_submit(
    conn,
    %{
      "email" => email,
      "first_name" => first_name,
      "last_name" => last_name,
      "password" => password,
      "password_confirmation" => password_confirmation
    })
  do
    user_params = %{
      email: email,
      first_name: first_name,
      last_name: last_name,
      provider: "identity",
      password: password,
      password_confirmation: password_confirmation,
      email_verified: false
    }

    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Thank you for registering!")
        |> put_session(:user_id, user.id)
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Routes.auth_path(conn, :signin))
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
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

  def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    %Ueberauth.Auth{info: %{email: email}, credentials: %{other: %{password: password}}} = auth;

    case Accounts.authorize_user(email, password) do
      { :ok, user } ->
        conn
        |> put_flash(:info, "Thank you for signing in!")
        |> put_session(:user_id, user.id)
        |> redirect(to: Routes.page_path(conn, :index))
      { :error, reason } ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: Routes.auth_path(conn, :signin))
    end
  end

end

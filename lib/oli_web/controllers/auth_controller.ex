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

  def register_email(conn, _params) do
    render(conn, "register_email.html", callback_url: Helpers.callback_url(conn))
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do

    IO.inspect(auth)

    user_params = %{
      # token: auth.credentials.token,
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      email: auth.info.email,
      provider: "google"
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

end

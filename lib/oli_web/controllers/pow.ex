defmodule OliWeb.PowController do
  use OliWeb, :controller

  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Pow.Phoenix.Controller
  alias Pow.Phoenix.Routes, as: PowRoutes
  alias PowResetPassword.Phoenix.ResetPasswordController
  alias Oli.Repo

  @ttl :timer.minutes(24 * 60)
  @cache_config {PowResetPassword.Store.ResetTokenCache, ttl: @ttl}

  @doc """
  Create a password reset link for a user or author that will expire in
  the amount of time defined in @ttl (currently 24 hours).

  id: the id of the user or author
  account_type: :user or :author
  """
  def create_password_reset_link(%{"id" => id}, account_type) do
    %{email: email} =
      account_type
      |> schema_for_type()
      |> Repo.get(id)

    params = %{"user" => %{"email" => email}}

    secret_key_base = Application.get_env(:oli, OliWeb.Endpoint)[:secret_key_base]
    app_conf = %{phoenix_router: OliWeb.Router, phoenix_endpoint: OliWeb.Endpoint, otp_app: :oli}

    %Plug.Conn{}
    |> Map.replace(:private, app_conf)
    |> Map.replace(:secret_key_base, secret_key_base)
    |> use_pow_config(account_type)
    |> put_reset_password_token_store_into_pow_config()
    |> ResetPasswordController.process_create(params)
    |> generate_password_reset_url()
  end

  defp schema_for_type(:author), do: Author
  defp schema_for_type(:user), do: User

  def send_user_password_reset_link(conn, %{"user_id" => id}) do
    user = Repo.get(User, id)

    conn
    |> use_pow_config(:user)
    |> PowResetPassword.Phoenix.ResetPasswordController.process_create(%{
      "user" => %{"email" => user.email}
    })
    |> password_reset_respond_create()
    |> put_flash(:info, "Password reset link sent to user #{user.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Users.UsersDetailView, user.id))
  end

  def send_author_password_reset_link(conn, %{"user_id" => id}) do
    author = Repo.get(Author, id)

    conn
    |> use_pow_config(:author)
    |> PowResetPassword.Phoenix.ResetPasswordController.process_create(%{
      "user" => %{"email" => author.email}
    })
    |> password_reset_respond_create()
    |> put_flash(:info, "Password reset link sent to user #{author.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Users.AuthorsDetailView, author.id))
  end

  defp password_reset_respond_create({:ok, %{token: token, user: user}, conn}) do
    url =
      Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).url_for(
        conn,
        PowResetPassword.Phoenix.ResetPasswordController,
        :edit,
        [token]
      )

    email = PowResetPassword.Phoenix.Mailer.reset_password(conn, user, url)
    Pow.Phoenix.Mailer.deliver(conn, email)

    conn
  end

  def resend_user_confirmation_link(conn, %{"user_id" => id}) do
    user = Repo.get(User, id)

    conn
    |> use_pow_config(:user)
    |> resend_user_confirmation_email(user)
    |> put_flash(:info, "Confirmation link sent to user #{user.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Users.UsersDetailView, user.id))
  end

  def resend_author_confirmation_link(conn, %{"user_id" => id}) do
    author = Repo.get(Author, id)

    conn
    |> use_pow_config(:author)
    |> resend_user_confirmation_email(author)
    |> put_flash(:info, "Confirmation link sent to admin #{author.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Users.AuthorsDetailView, author.id))
  end

  defp generate_password_reset_url({:ok, %{token: token, user: _user}, conn}) do
    Controller.routes(conn, PowRoutes).url_for(conn, ResetPasswordController, :edit, [token])
  end

  defp put_reset_password_token_store_into_pow_config(conn) do
    update_in(
      conn,
      [Access.key(:private), Access.key(:pow_config)],
      &Keyword.put(&1, :reset_password_token_store, @cache_config)
    )
  end

  defp resend_user_confirmation_email(conn, user) do
    PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email(user, conn)
    conn
  end
end

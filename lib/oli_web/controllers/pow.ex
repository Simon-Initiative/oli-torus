defmodule OliWeb.PowController do
  use OliWeb, :controller

  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Accounts.Author

  def send_user_password_reset_link(conn, %{"id" => id}) do
    user = Repo.get(User, id)

    conn
    |> use_pow_config(:user)
    |> PowResetPassword.Phoenix.ResetPasswordController.process_create(%{
      "user" => %{"email" => user.email}
    })
    |> password_reset_respond_create()
    |> put_flash(:info, "Password reset link sent to user #{user.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Accounts.AccountsLive, %{active_tab: :users}))
  end

  def send_author_password_reset_link(conn, %{"id" => id}) do
    author = Repo.get(Author, id)

    conn
    |> use_pow_config(:author)
    |> PowResetPassword.Phoenix.ResetPasswordController.process_create(%{
      "user" => %{"email" => author.email}
    })
    |> password_reset_respond_create()
    |> put_flash(:info, "Password reset link sent to user #{author.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Accounts.AccountsLive, %{active_tab: :authors}))
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

  def resend_user_confirmation_link(conn, %{"id" => id}) do
    user = Repo.get(User, id)

    conn
    |> use_pow_config(:user)
    |> resend_user_confirmation_email(user)
    |> put_flash(:info, "Confirmation link sent to user #{user.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Accounts.AccountsLive, %{active_tab: :users}))
  end

  def resend_author_confirmation_link(conn, %{"id" => id}) do
    author = Repo.get(Author, id)

    conn
    |> use_pow_config(:author)
    |> resend_user_confirmation_email(author)
    |> put_flash(:info, "Confirmation link sent to admin #{author.email}.")
    |> redirect(to: Routes.live_path(conn, OliWeb.Accounts.AccountsLive, %{active_tab: :authors}))
  end

  defp resend_user_confirmation_email(conn, user) do
    PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email(user, conn)
    conn
  end
end

defmodule OliWeb.PowController do
  use OliWeb, :controller

  alias Oli.Repo
  alias Oli.Accounts.User
  alias Oli.Accounts.Author

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
    |> redirect(to: Routes.live_path(conn, OliWeb.Accounts.AccountsLive, %{active_tab: :author}))
  end

  defp resend_user_confirmation_email(conn, user) do
    PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email(user, conn)
    conn
  end
end

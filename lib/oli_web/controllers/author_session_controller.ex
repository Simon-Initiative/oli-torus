defmodule OliWeb.AuthorSessionController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.AuthorAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, flash_message: "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:author_return_to, ~p"/authors/settings")
    |> create(params, flash_message: "Password updated successfully!")
  end

  def create(conn, params) do
    conn
    |> AuthorAuth.maybe_store_link_account_user_id(params["author"])
    |> create(params, flash_message: "Welcome back!")
  end

  def create(conn, %{"author" => author_params}, opts) do
    %{"email" => email, "password" => password} = author_params

    if author = Accounts.get_author_by_email_and_password(email, password) do
      conn
      |> maybe_add_flash_message(opts[:flash_message])
      |> AuthorAuth.log_in_author(author, author_params)
    else
      # in the case where this login originates from the link account page, the redirect_to is set
      # to the link account page. Otherwise, it is set to the author log in page.
      {conn, redirect_to} =
        if get_session(conn, :link_account_user_id) do
          {delete_session(conn, :link_account_user_id), ~p"/users/link_account"}
        else
          {conn, ~p"/authors/log_in"}
        end

      # In order to prevent author enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: redirect_to)
    end
  end

  def delete(conn, params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AuthorAuth.log_out_author(params)
  end

  defp maybe_add_flash_message(conn, nil), do: conn
  defp maybe_add_flash_message(conn, message), do: conn |> put_flash(:info, message)
end

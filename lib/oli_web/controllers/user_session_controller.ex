defmodule OliWeb.UserSessionController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.UserAuth
  alias Oli.Delivery.Sections

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, flash_message: "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, flash_message: "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, flash_message: "Welcome back!")
  end

  def create(conn, %{"user" => user_params} = params, opts) do
    %{"email" => email, "password" => password} = user_params

    user_params =
      if Map.get(params, "request_path") do
        Map.put(user_params, "request_path", Map.get(params, "request_path"))
      else
        user_params
      end

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> maybe_add_flash_message(opts[:flash_message])
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  defp maybe_add_flash_message(conn, nil), do: conn
  defp maybe_add_flash_message(conn, message), do: conn |> put_flash(:info, message)

  def delete(conn, _params) do
    user = Map.get(conn.assigns, :current_user)

    redirect_to =
      if !is_nil(user) && Sections.is_independent_instructor?(user) do
        ~p"/instructors/log_in"
      else
        ~p"/"
      end

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user(%{"redirect_to" => redirect_to})
  end
end

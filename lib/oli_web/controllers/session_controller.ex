defmodule OliWeb.SessionController do
  use OliWeb, :controller

  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  alias OliWeb.Pow.{PowHelpers, SessionUtils, UserRoutes}
  alias Pow.Plug

  plug :require_authenticated when action in [:signout]

  def signin(conn, %{"user" => user_params} = params) do
    pow_config_type =
      (params["type"] || "user")
      |> String.to_existing_atom()

    is_authenticated? =
      PowHelpers.use_pow_config(conn, pow_config_type)
      |> Plug.authenticate_user(user_params)

    case is_authenticated? do
      {:ok, conn} ->
        after_sign_in_target =
          (params["after_sign_in_target"] || "student_workspace") |> String.to_existing_atom()

        conn
        |> redirect(to: UserRoutes.after_sign_in_path(conn, after_sign_in_target))

      {:error, conn} ->
        conn
        |> assign(:changeset, Plug.change_user(conn, conn.params["user"]))
        |> put_flash(
          :error,
          "The provided login details did not work. Please verify your credentials, and try again."
        )
        |> on_sign_in_error(params["after_sign_in_target"])
    end
  end

  def signout(conn, %{"type" => type} = params) do
    conn
    |> SessionUtils.perform_signout(type)
    |> signout_redirect(params)
  end

  defp signout_redirect(conn, params) do
    case params["target"] do
      path when path in ["", nil] ->
        redirect(conn, to: Routes.static_page_path(conn, :index))

      path ->
        redirect(conn, to: path)
    end
  end

  defp on_sign_in_error(conn, nil), do: redirect(conn, to: ~p"/")

  defp on_sign_in_error(conn, after_sign_in_target) do
    after_sign_in_target =
      (after_sign_in_target || "student_workspace") |> String.to_existing_atom()

    redirect(conn, to: UserRoutes.after_sign_in_path(conn, after_sign_in_target))
  end
end

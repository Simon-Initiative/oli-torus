defmodule OliWeb.SessionController do
  use OliWeb, :controller

  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  alias Oli.AccountLookupCache
  alias OliWeb.Pow.{PowHelpers, UserRoutes}
  alias Pow.Plug

  plug :require_authenticated when action in [:signout]

  @shared_session_data_to_delete [:dismissed_messages]

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
    |> delete_cache_entry(type)
    |> delete_pow_user(String.to_atom(type))
    |> delete_session_data(type)
    |> delete_session("completed_section_surveys")
    |> delete_session("visited_sections")
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

  defp delete_session_data(conn, type) do
    Enum.reduce(session_data_to_delete(type), conn, fn field, acc_conn ->
      delete_session(acc_conn, field)
    end)
  end

  defp session_data_to_delete(type),
    do: [String.to_atom("current_#{type}_id") | @shared_session_data_to_delete]

  defp delete_cache_entry(conn, type) do
    id =
      conn.assigns
      |> Map.get(String.to_existing_atom("current_#{type}"))
      |> Map.get(:id)

    AccountLookupCache.delete("#{type}_#{id}")

    conn
  end
end

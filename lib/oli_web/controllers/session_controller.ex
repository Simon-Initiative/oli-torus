defmodule OliWeb.SessionController do
  use OliWeb, :controller

  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  alias Oli.AccountLookupCache
  alias OliWeb.Pow.{PowHelpers, UserRoutes}
  alias Pow.Plug

  plug :require_authenticated when action in [:signout]

  @shared_session_data_to_delete [:dismissed_messages]

  def signin(conn, %{"user" => user_params}) do
    is_authenticated? =
      PowHelpers.use_pow_config(conn, :user)
      |> Plug.authenticate_user(user_params)

    case is_authenticated? do
      {:ok, conn} ->
        conn
        |> redirect(to: UserRoutes.after_sign_in_path(conn))

      {:error, conn} ->
        conn
        |> assign(:changeset, Plug.change_user(conn, conn.params["user"]))
        |> put_flash(
          :error,
          "The provided login details did not work. Please verify your credentials, and try again."
        )
        |> redirect(to: ~p"/")
    end
  end

  def signout(conn, %{"type" => type}) do
    conn
    |> delete_cache_entry(type)
    |> delete_pow_user(String.to_atom(type))
    |> delete_session_data(type)
    |> delete_session("completed_section_surveys")
    |> delete_session("visited_sections")
    |> redirect(to: Routes.static_page_path(conn, :index))
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

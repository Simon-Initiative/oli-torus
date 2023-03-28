defmodule OliWeb.SessionController do
  use OliWeb, :controller

  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  alias Oli.AccountLookupCache

  plug :require_authenticated when action in [:signout]

  @shared_session_data_to_delete [:dismissed_messages]

  def signout(conn, %{"type" => type}) do
    conn
    |> delete_cache_entry(type)
    |> delete_pow_user(String.to_atom(type))
    |> delete_session_data(type)
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

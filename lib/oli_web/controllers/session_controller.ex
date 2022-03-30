defmodule OliWeb.SessionController do
  use OliWeb, :controller

  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  plug :require_authenticated when action in [:signout]

  @shared_session_data_to_delete [:dismissed_messages]

  def signout(conn, %{"type" => type}) do
    conn
    |> use_pow_config(String.to_atom(type))
    |> Pow.Plug.delete()
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
end

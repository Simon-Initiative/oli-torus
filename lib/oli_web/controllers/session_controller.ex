defmodule OliWeb.SessionController do
  use OliWeb, :controller

  require Logger
  import Pow.Phoenix.Controller, only: [require_authenticated: 2]

  plug :require_authenticated when action in [:signout]

  @session_data_to_delete [:dismissed_messages]

  def signout(conn, %{"type" => type}) do
    Logger.error("Signing out with user type #{type}")

    conn
    |> use_pow_config(String.to_atom(type))
    |> Pow.Plug.delete()
    |> delete_session_data()
    |> redirect(to: Routes.static_page_path(conn, :index))
  end

  defp delete_session_data(conn) do
    Enum.reduce(@session_data_to_delete, conn, fn field, acc_conn ->
      delete_session(acc_conn, field)
    end)
  end
end

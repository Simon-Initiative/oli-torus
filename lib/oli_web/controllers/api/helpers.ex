defmodule OliWeb.Api.Helpers do
  import Plug.Conn

  def error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

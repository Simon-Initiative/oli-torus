defmodule Oli.Plugs.Protect do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn = fetch_session(conn)
      if get_session(conn, :current_user_id) do
        conn
      else
        conn
          |> redirect(to: OliWeb.Router.Helpers.auth_path(conn, :signin))
          |> halt()
      end
    end
  end
end

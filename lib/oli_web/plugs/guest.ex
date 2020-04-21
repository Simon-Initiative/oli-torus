defmodule OliWeb.Plugs.Guest do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if Plug.Conn.get_session(conn, :author_id) do
      conn
      |> redirect(to: OliWeb.Router.Helpers.static_page_path(conn, :index))
      |> halt()
    end
    conn
  end
end

defmodule Oli.Plugs.Protect do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Accounts.User
  alias Oli.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:user] do
      conn
    else
      conn = fetch_session(conn)
      if user_id = get_session(conn, :user_id) do
        conn
      else
        conn
          |> redirect(to: OliWeb.Router.Helpers.auth_path(conn, :signin))
          |> halt()
      end
    end
  end
end

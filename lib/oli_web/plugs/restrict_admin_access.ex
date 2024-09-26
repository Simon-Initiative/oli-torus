defmodule Oli.Plugs.RestrictAdminAccess do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if Oli.Accounts.has_admin_role?(conn.assigns[:current_author]) do
      conn
      |> put_flash(:error, "Admins are not allowed to access this page.")
      |> redirect(to: ~p"/workspaces/course_author")
      |> halt()
    else
      conn
    end
  end
end

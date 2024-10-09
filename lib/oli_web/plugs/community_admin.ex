defmodule Oli.Plugs.CommunityAdmin do
  use OliWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if Plug.Conn.get_session(conn, :is_system_admin) or
         Plug.Conn.get_session(conn, :is_community_admin) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:info, "You are not allowed to access Communities")
      |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
      |> Plug.Conn.halt()
    end
  end
end

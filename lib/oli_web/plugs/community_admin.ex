defmodule Oli.Plugs.CommunityAdmin do
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if Plug.Conn.get_session(conn, :is_system_admin) or
         Plug.Conn.get_session(conn, :is_community_admin) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:info, "You are not allowed to access Communities")
      |> Phoenix.Controller.redirect(
        to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
      )
      |> Plug.Conn.halt()
    end
  end
end

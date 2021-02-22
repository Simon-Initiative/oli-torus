defmodule OliWeb.ProjectPlugs do

  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes

  def fetch_project(conn, _) do
    case Course.get_project_by_slug(conn.params["project_id"]) do
      nil ->
        conn
        |> Phoenix.Controller.put_flash(:info, "That project does not exist")
        |> Phoenix.Controller.redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
        |> Plug.Conn.halt()
      project -> conn
        |> Plug.Conn.assign(:project, project)
    end
  end

  def authorize_project(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      conn
       |> Phoenix.Controller.put_flash(:info, "You don't have access to that project")
       |> Phoenix.Controller.redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
       |> Plug.Conn.halt()
    end
  end

end

defmodule Oli.Plugs.AuthorizeProject do
  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case Course.get_project_by_slug(conn.params["project_id"]) do
      nil ->
        conn
        |> Phoenix.Controller.put_flash(:info, "That project does not exist")
        |> Phoenix.Controller.redirect(
          to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
        )
        |> Plug.Conn.halt()

      project ->
        if Accounts.can_access?(conn.assigns[:current_author], project) && project.status === :active do
          conn
          |> Plug.Conn.assign(:project, project)
          |> Plug.Conn.assign(:project_id, project.slug)
        else
          conn
          |> Phoenix.Controller.put_flash(:info, "You don't have access to that project")
          |> Phoenix.Controller.redirect(
            to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
          )
          |> Plug.Conn.halt()
        end
    end
  end
end

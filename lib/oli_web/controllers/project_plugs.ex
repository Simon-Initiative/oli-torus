defmodule OliWeb.ProjectPlugs do
  use OliWeb, :verified_routes

  alias Oli.Authoring.Course
  alias Oli.Accounts

  def fetch_project(conn, _) do
    case Course.get_project_by_slug(conn.params["project_id"]) do
      nil ->
        conn
        |> Phoenix.Controller.put_flash(:info, "That project does not exist")
        |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
        |> Plug.Conn.halt()

      project ->
        conn
        |> Plug.Conn.assign(:project, project)
    end
  end

  def authorize_project(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:info, "You don't have access to that project")
      |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
      |> Plug.Conn.halt()
    end
  end

  def fetch_project_api(conn, _) do
    case Course.get_project_by_slug(conn.params["project"]) do
      nil ->
        error(conn, 404, "Project not found")

      project ->
        conn
        |> Plug.Conn.assign(:project, project)
    end
  end

  def authorize_project_api(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      error(conn, 403, "Not authorized")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> Plug.Conn.send_resp(code, reason)
    |> Plug.Conn.halt()
  end
end

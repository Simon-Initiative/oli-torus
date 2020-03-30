defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  alias Oli.Course
  alias Oli.Accounts

  plug :fetch_project when not action in [:create]
  plug :authorize_project when not action in [:create]

  def overview(conn, %{"project" => project_id}) do
    params = %{title: "Overview", project: project_id, active: :overview}
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html"
  end

  def objectives(conn, %{"project" => project_id}) do
    render conn, "objectives.html", title: "Objectives", project: project_id, active: :objectives
  end

  def curriculum(conn, %{"project" => project_id}) do
    render conn, "curriculum.html", title: "Curriculum", project: project_id, active: :curriculum
  end

  def page(conn, %{"project" => project_id}) do
    render conn, "page.html", title: "Page", project: project_id, active: :page
  end

  def resource_editor(conn, %{"project" => project_id}) do
    render conn, "resource_editor.html", title: "Resource Editor", project: project_id, active: :resource_editor
  end

  def publish(conn, %{"project" => project_id}) do
    render conn, "publish.html", title: "Publish", project: project_id, active: :publish
  end

  def insights(conn, %{"project" => project_id}) do
    render conn, "insights.html", title: "Insights", project: project_id, active: :insights
  end

  def create(conn, %{"project" => %{"title" => title} = _project_attrs}) do
      case Course.create_project(title, conn.assigns.current_author) do
        {:ok, %{project: project} = _results} ->
          redirect conn, to: Routes.project_path(conn, :overview, project)
        {:error, _failed_operation, _failed_value, _changes_before_failure} ->
          conn
            |> put_flash(:error, "Could not create project. Please try again")
            |> redirect(to: Routes.workspace_path(conn, :projects, project_title: title))
      end
  end

  defp fetch_project(conn, _) do
    case Course.get_project_by_slug(conn.params["project"]) do
      nil ->
        conn
        |> put_flash(:info, "That project does not exist")
        |> redirect(to: Routes.workspace_path(conn, :projects))
        |> halt()
      project -> conn
        |> assign(:project, project)
    end
  end

  defp authorize_project(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      conn
       |> put_flash(:info, "You don't have access to that project")
       |> redirect(to: Routes.workspace_path(conn, :projects))
       |> halt()
    end
  end
end

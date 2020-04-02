defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  alias Oli.Course
  alias Oli.Accounts
  alias Oli.Publishing
  alias Oli.Learning

  require Logger

  plug :fetch_project when not action in [:create]
  plug :authorize_project when not action in [:create]

  def overview(conn, %{"project" => project_id}) do
    params = %{title: "Overview", active: :overview}
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html"
  end

  def objectives(conn, %{"project" => project_id}) do
    project = Course.get_project_by_slug(conn.params["project"])
    publication_id = Publishing.get_unpublished_publication(project.id)
    objective_mappings = Publishing.get_objective_mappings_by_publication(publication_id)
    Logger.info "objective_mappings #{inspect(objective_mappings)}"
    changeset = Learning.change_objective(%Learning.Objective{})
    params = %{title: "Objectives", objective_mappings: objective_mappings, objective_changeset: changeset}
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
  end

  def curriculum(conn, %{"project" => project_id}) do
    render conn, "curriculum.html", title: "Curriculum", active: :curriculum
  end

  def page(conn, %{"project" => project_id}) do
    render conn, "page.html", title: "Page", active: :page
  end

  def resource_editor(conn, %{"project" => project_id}) do
    render conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor
  end

  def publish(conn, %{"project" => project_id}) do
    render conn, "publish.html", title: "Publish", active: :publish
  end

  def insights(conn, %{"project" => project_id}) do
    render conn, "insights.html", title: "Insights", active: :insights
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

defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  alias Oli.Course

  def overview(conn, %{"project" => project_id, }) do
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

  def create(conn, %{"project" => project_params }) do
    IO.inspect(project_params)
    case Course.create_project(project_params) do
      {:ok, project} ->
        conn
        |> redirect(to: Routes.project_path(conn, :overview, project_params["id"]))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, OliWeb.WorkspaceView, "projects.html", changeset: changeset, project_title: project_params["title"])
    end
  end
end

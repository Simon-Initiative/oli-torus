defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Accounts
  alias Oli.Utils
  alias Oli.Authoring.{Course}
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing

  plug :fetch_project when action not in [:create]
  plug :authorize_project when action not in [:create]

  def overview(conn, project_params) do
    project = conn.assigns.project
    params = %{
      title: "Overview",
      active: :overview,
      collaborators: Accounts.project_authors(project),
      changeset: Utils.value_or(
        Map.get(project_params, :changeset),
        Project.changeset(project)),
    }
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html"
  end

  def objectives(conn, _request_params) do
    project = conn.assigns.project
    params = Oli.Authoring.Editing.ObjectiveEditor.fetch_objective_mappings_params(project)
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
  end

  def edit_objective(conn, request_params) do
    project = conn.assigns.project
    params = Oli.Authoring.Editing.ObjectiveEditor.fetch_objective_mappings_params(project)
    case Map.get(request_params, "action") do
      "edit_objective" ->
        params = Map.merge(params, %{edit: Map.get(request_params, "objective_slug")})
        render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
      "add_sub_objective" ->
        params = Map.merge(params, %{edit: "add_sub_"<>Map.get(request_params, "objective_slug")})
        render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
      nil ->
        render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
    end
  end

  def unpublished(pub), do: pub.published == false

  def resource_editor(conn, _project_params) do
    render conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor
  end

  def publish(conn, _project_params) do
    project = conn.assigns.project
    latest_published_publication = Publishing.get_latest_published_publication_by_slug!(project.slug)
    active_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)

    {has_changes, active_publication_changes} = case latest_published_publication do
      nil -> {true, nil}
      _ ->
        changes = Publishing.diff_publications(latest_published_publication, active_publication)
          |> (&(:maps.filter fn _, v -> v != :identical end, &1)).()
        has_changes = Map.values(changes)
          |> Enum.any?(fn {status, _} -> status != :identical end)
        {has_changes, changes}
      end

    render conn, "publish.html", title: "Publish", active: :publish, latest_published_publication: latest_published_publication, active_publication_changes: active_publication_changes, has_changes: has_changes
  end

  def publish_active(conn, _params) do
    project = conn.assigns.project
    Publishing.publish_project(project)

    conn
    |> put_flash(:info, "Publish Successful!")
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end

  def insights(conn, _project_params) do
    render conn, "insights.html", title: "Insights", active: :insights
  end

  def create(conn, %{"project" => %{"title" => title} = _project_params}) do
      case Course.create_project(title, conn.assigns.current_author) do
        {:ok, %{project: project}} ->
          redirect conn, to: Routes.project_path(conn, :overview, project)
        {:error, _changeset} ->
          conn
            |> put_flash(:error, "Could not create project. Please try again")
            |> redirect(to: Routes.workspace_path(conn, :projects, project_title: title))
      end
  end

  def update(conn, %{"project" => project_params}) do
    project = conn.assigns.project
    case Course.update_project(project, project_params) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project updated successfully.")
        |> redirect(to: Routes.project_path(conn, :overview, project))

      {:error, %Ecto.Changeset{} = changeset} ->
        overview_params = %{
          title: "Overview",
          active: :overview,
          collaborators: Accounts.project_authors(project),
          changeset: changeset
        }
        conn
        |> Map.put(:assigns, Map.merge(conn.assigns, overview_params))
        |> put_flash(:error, "Project could not be updated.")
        |> render("overview.html")
    end
  end
end

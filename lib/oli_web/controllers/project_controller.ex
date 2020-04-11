defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Course.Project
  alias Oli.Accounts
  alias Oli.Utils
  alias Oli.Course
  alias Oli.Publishing
  alias Oli.Learning

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

  def objectives(conn, _params) do
    project = conn.assigns.project
    publication_id = Publishing.get_unpublished_publication(project.id)
    objective_mappings = Publishing.get_objective_mappings_by_publication(publication_id)
    changeset = Learning.change_objective(%Learning.Objective{})
    params = %{title: "Objectives", objective_mappings: objective_mappings, objective_changeset: changeset, active: :objectives}
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "objectives.html"
  end

  def unpublished(pub), do: pub.published == false

  def curriculum(conn, _project_params) do
    publication = Publishing.get_unpublished_publication(conn.assigns.project)
    resource_mappings = Publishing.get_resource_mappings_by_publication(publication.id)
    [container_id | _] = publication.root_resources
    container = Oli.Repo.preload(Oli.Resources.get_resource!(container_id), [:resource_revisions])
    revision = container.resource_revisions
      |> Enum.max_by(&(&1.inserted_at), NaiveDateTime)
    IO.inspect(revision)
    pages = Enum.map(revision.children, &(Oli.Resources.get_resource!(&1)))

    render conn, "curriculum.html", title: "Curriculum", active: :curriculum, pages: pages, container_revision: revision

    # display as list
    # make each list item a title with a link to the page
  end

  def page(conn, _project_params) do
    render conn, "page.html", title: "Page", active: :page
  end

  def resource_editor(conn, _project_params) do
    render conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor
  end

  def publish(conn, _project_params) do
    render conn, "publish.html", title: "Publish", active: :publish
  end

  def insights(conn, _project_params) do

    render conn, "insights.html", title: "Insights", active: :insights
  end

  def create(conn, %{"project" => %{"title" => title} = _project_params}) do
      case Course.create_project(title, conn.assigns.current_author) do
        {:ok, %{project: project} = _results} ->
          redirect conn, to: Routes.project_path(conn, :overview, project)
        {:error, _failed_operation, _failed_value, _changes_before_failure} ->
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

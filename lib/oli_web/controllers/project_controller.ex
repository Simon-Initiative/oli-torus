defmodule OliWeb.ProjectController do
  use OliWeb, :controller
  alias Oli.Publishing
  alias Oli.Resources
  alias Oli.Course
  alias Oli.Accounts
  alias Oli.Repo
  alias Ecto.Multi

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

  def create(conn, %{"project" => %{"title" => title} = project_attrs}) do
    # Here's how this works:
    # Multi chains database operations and performs a single transaction at the end.
    # If one operation fails, the changes are rolled back.
    # `insert` takes a changeset in order to create a new row, and `merge` takes a lambda
    # that allows you to access the changesets created in previous Multi calls
    result = Multi.new
      |> Multi.insert(:family, Course.default_family(title))
      |> Multi.merge(fn %{family: family} ->
        Multi.new
          |> Multi.insert(:project, Course.default_project(title, family)) end)
      |> Multi.merge(fn %{project: project} ->
        Multi.new
          |> Multi.update(:author, Accounts.author_to_project(conn.assigns.current_author, project))
          |> Multi.insert(:resource, Resources.new_project_resource(project)) end)
      |> Multi.merge(fn %{author: author, project: project, resource: resource} ->
        Multi.new
        |> Multi.insert(:resource_revision, Resources.new_project_resource_revision(author, project, resource))
        |> Multi.insert(:publication, Publishing.new_project_publication(resource, project)) end)
      |> Repo.transaction

      IO.inspect(result)

      case result do
        {:ok, %{project: project} = results} ->
          redirect conn, to: Routes.project_path(conn, :overview, project)
        {:error, _failed_operation, _failed_value, _changes_before_failure} ->
          conn
            |> put_flash(:error, "Could not create project. Please try again")
            |> redirect(to: Routes.workspace_path(conn, :projects, project_title: title))
      end
  end
end

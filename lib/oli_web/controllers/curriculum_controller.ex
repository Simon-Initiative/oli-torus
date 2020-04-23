defmodule OliWeb.CurriculumController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Authoring.Resources

  plug :fetch_project
  plug :authorize_project

  def index(conn, _params) do
    render(conn, "index.html",
      pages: Resources.list_all_pages(conn.assigns.project),
      title: "Curriculum")
  end

  def create(conn, %{"type" => type}) do
    %{ project: project, current_author: author } = conn.assigns
    resource_type = case type do
      "Scored" -> Resources.resource_type.scored_page
      "Unscored" -> Resources.resource_type.unscored_page
      _ -> Resources.resource_type.unscored_page
    end

    case Resources.create_project_resource(
      %{
        objectives: [],
        children: [],
        content: [],
        title: "New #{type} Page",
      }, resource_type, author, project
    ) do
      {:ok, _resource} ->
        conn
        |> redirect(to: Routes.curriculum_path(conn, :index, project))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Could not create page")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))
    end
  end

  def update(conn, %{"update" => update_params}) do
    %{project: project, current_author: author} = conn.assigns

    case Resources.update_root_container_children(project, author, update_params) do
      {:ok, _resource} ->
        render(conn, "index.html",
        pages: Resources.list_all_pages(conn.assigns.project),
        title: "Curriculum")

      {:error, _} ->
        render(conn, "index.html",
        pages: Resources.list_all_pages(conn.assigns.project),
        title: "Curriculum")
    end
  end

end

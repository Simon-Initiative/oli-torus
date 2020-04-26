defmodule OliWeb.CurriculumController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Resources

  plug :fetch_project
  plug :authorize_project

  def index(conn, _params) do
    render(conn, "index.html",
      pages: ContainerEditor.list_all_pages(conn.assigns.project),
      title: "Curriculum")
  end

  def create(conn, %{"type" => type}) do
    %{ project: project, current_author: author } = conn.assigns

    attrs = %{
      objectives: %{ "attached" => []},
      children: [],
      content: %{ "model" => []},
      title: "New Page",
      graded: type == "Scored",
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    case ContainerEditor.add_new(attrs, author, project) do

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
        pages: ContainerEditor.list_all_pages(conn.assigns.project),
        title: "Curriculum")

      {:error, _} ->
        render(conn, "index.html",
        pages: ContainerEditor.list_all_pages(conn.assigns.project),
        title: "Curriculum")
    end
  end

end

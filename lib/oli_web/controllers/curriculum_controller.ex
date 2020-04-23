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

  def create(conn, _params) do
    %{ project: project, current_author: author } = conn.assigns

    case Resources.create_project_resource(
      %{
        objectives: [],
        children: [],
        content: [],
        title: "New Page",
      }, Resources.resource_type.unscored_page, author, project
    ) do
      {:ok, _resource} ->
        conn
        |> put_flash(:info, "New page created")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Could not create page")
        |> redirect(to: Routes.curriculum_path(conn, :index, project))
    end
  end

  def update(conn, %{"update" => update_params} = params) do
    %{project: project, current_author: author} = conn.assigns
    IO.inspect(params, label: "update params")

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

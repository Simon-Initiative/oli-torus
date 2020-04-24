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

  def create(conn, _params) do
    %{ project: project, current_author: author } = conn.assigns

    attrs = %{
      objectives: %{ "attached" => []},
      children: [],
      content: %{ "model" => []},
      title: "New Page",
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page")
    }

    case ContainerEditor.add_new(attrs, author, project) do
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

  def update(conn, %{"id" => id, "resource" => resource_params}) do
    # handle re-ordering here. Take full list of id's, set root container children with new ids
    resource = Resources.get_resource!(id)

    case Resources.update_resource(resource, resource_params) do
      {:ok, _resource} ->
        conn
        |> put_flash(:info, "resource updated successfully.")
        |> redirect(to: Routes.curriculum_path(conn, :index, conn.assigns.project))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", resource: resource, changeset: changeset)
    end
  end

end

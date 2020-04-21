defmodule OliWeb.CurriculumController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Authoring.Resources

  plug :fetch_project
  plug :authorize_project

  def index(conn, _params) do
    # for the pages, preload the resource type
    # write a utility for displaying what the "convert" button will do -> convert to scored or unscored
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

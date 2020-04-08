defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  alias Oli.ResourceEditing
  import OliWeb.ProjectPlugs

  plug :fetch_project when action not in [:view, :update]
  plug :authorize_project when action not in [:view]

  def view(conn, %{"project" => _project_id}) do
    render conn, "page.html", title: "Page", active: :page
  end

  def edit(conn, %{"project" => _project_id}) do
    render conn, "edit.html", title: "Resource Editor", active: :resource_editor
  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug }) do

    current_author_id

    case ResourceEditing.edit(project_slug, resource_slug, author, update) do
      {:ok, _revision} -> json conn, %{ "type" => "success"}
      {:error, {:lock_not_acquired}} -> json conn, %{ "type" => "lock_not_acquired"}
      {:error, {:not_found}} -> json conn, %{ "type" => "not_found"}
      _ -> json conn, %{ "type" => "error"}
    end

  end

end

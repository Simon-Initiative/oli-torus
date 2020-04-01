defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  import OliWeb.ProjectPlugs

  plug :fetch_project when action not in [:view]
  plug :authorize_project when action not in [:view]

  def view(conn, %{"project" => _project_id}) do
    render conn, "page.html", title: "Page", active: :page
  end

  def edit(conn, %{"project" => _project_id}) do
    render conn, "edit.html", title: "Resource Editor", active: :resource_editor
  end

  def update(conn, %{"project" => _project_id, "resource" => _resource_id }) do
    json conn, %{ "type" => "success"}
  end

end

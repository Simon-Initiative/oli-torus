defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  def view(conn, %{"project" => project_id}) do
    render conn, "page.html", title: "Page", project: project_id, active: :page
  end

  def edit(conn, %{"project" => project_id}) do
    render conn, "edit.html", title: "Resource Editor", project: project_id, active: :resource_editor
  end

  def update(conn, %{"project" => _project_id, "resource" => _resource_id }) do
    json conn, %{ "type" => "success"}
  end

end

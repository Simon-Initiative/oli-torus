defmodule OliWeb.ObjectiveController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.{Course, Learning, Utils}
  alias Oli.Publishing

  plug :fetch_project when action in [:create, :update, :delete]
  plug :authorize_project when action in [:create, :update, :delete]

  def create(conn, %{"project_id" => project_id, "objective" => objective_params}) do
    project = conn.assigns.project
    params = Map.merge(objective_params, %{"project_id" => project.id, "project_slug" => project.slug})
    with {:ok, _objective} <- Learning.create_objective(params)
    do
      conn
      |> put_flash(:info, "Objective created successfully.")
      |> put_req_header("x-status", "success")
      |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    else
      error ->
        conn
        |> put_flash(:error, "Objective creation failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def update(conn, %{"project_id" => project_id, "objective_slug" => objective_slug, "objective" => objective_params}) do
    project = conn.assigns.project
    params = Map.merge(objective_params, %{"project_id" => project.id, "project_slug" => project.slug})
    with {:ok, objective_revision} <- Learning.get_objective_revision_from_slug(project_id, objective_slug) |> trap_nil(),
         {:ok, _objective_revision} <- Learning.update_objective_revision(objective_revision, params)
    do
      conn
      |> put_flash(:info, "Objective updated successfully.")
      |> put_req_header("x-status", "success")
      |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    else
      error ->
        conn
        |> put_flash(:error, "Objective update failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def delete(conn, %{"project_id" => project_id, "objective_slug" => objective_slug}) do
    project = conn.assigns.project
    with {:ok, objective_revision} <- Learning.get_objective_revision_from_slug(project.slug, objective_slug) |> trap_nil(),
         {:ok, _objective_revision} <- Learning.delete_objective_revision(objective_revision)
    do
      conn
      |> put_flash(:info, "Objective deleted successfully.")
      |> put_req_header("x-status", "success")
      |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    else
      error ->
        conn
        |> put_flash(:error, "Objective delete failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  defp trap_nil(result) do
    case result do
      nil -> {:error, {:not_found}}
      _ -> {:ok, result}
    end
  end
end

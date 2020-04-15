defmodule OliWeb.ObjectiveController do
  require Logger
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Repo
  alias Oli.Course
  alias Oli.Learning
  alias Oli.Learning.Objective
  alias Oli.Learning.ObjectiveFamily

  alias Oli.Learning.ObjectiveRevision

  plug :fetch_project when action in [:create, :update, :delete]
  plug :authorize_project when action in [:create, :update, :delete]

  def create(conn, %{"project_id" => project_id, "objective" => objective_params}) do
    project = conn.assigns.project
    params = Map.merge(objective_params, %{"project_id" => project.id})
    Logger.info("Creating objective: #{inspect(params)}")
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

  def update(conn, %{"project_id" => project_id, "id" => id, "objective" => objective_params}) do
    project = conn.assigns.project
    params = Map.merge(objective_params, %{"project_id" => project.id})
    with {:ok, objective_revision} <- Repo.get(ObjectiveRevision, id) |> trap_nil(),
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

  def delete(conn, %{"project_id" => project_id, "id" => id}) do
    with {:ok, objective_revision} <- Repo.get(ObjectiveRevision, id) |> trap_nil(),
         {:ok, _objective_revision} <- Learning.update_objective_revision(objective_revision, %{deleted: true})
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

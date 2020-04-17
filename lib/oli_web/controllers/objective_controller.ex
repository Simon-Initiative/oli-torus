defmodule OliWeb.ObjectiveController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Authoring.{Course, Learning}

  plug :fetch_project when action in [:create, :update, :delete]
  plug :authorize_project when action in [:create, :update, :delete]

  def create(conn, %{"project_id" => project_id, "objective" => objective_params}) do
    project = conn.assigns.project
    params = Map.merge(objective_params, %{"project_id" => project.id})
    case Learning.create_objective(params) do
      {:ok, _objective} ->
        conn
        |> put_flash(:info, "Objective created successfully.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Objective creation failed.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def update(conn, %{"project_id" => project_id, "id" => id, "objective" => objective_params}) do
    objective = Learning.get_objective!(id)
    project = Course.get_project_by_slug(conn.params["project"])
    params = Map.merge(objective_params, %{"project_id" => project.id})
    case Learning.update_objective(objective, params) do
      {:ok, _objective} ->
        conn
        |> put_flash(:info, "Objective updated successfully.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Objective update failed.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def delete(conn, %{"project_id" => project_id, "id" => id}) do
    objective = Learning.get_objective!(id)
    {:ok, _objective} = Learning.delete_objective(objective)

    conn
    |> put_flash(:info, "Objective deleted successfully.")
    |> redirect(to: Routes.project_path(conn, :objectives, project_id))
  end

end

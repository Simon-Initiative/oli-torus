defmodule OliWeb.ObjectiveController do
  use OliWeb, :controller
  require Logger
  alias Oli.Course
  alias Oli.Learning
  alias Oli.Learning.Objective

#  plug :fetch_project when not action in [:create, :update, :delete]
#  plug :authorize_project when not action in [:create, :update, :delete]

  def create(conn, %{"project" => project_id, "objective" => objective_params}) do
    project = Course.get_project_by_slug(conn.params["project"])
    params = Map.merge(objective_params, %{"project_id" => project.id})
    case Learning.create_objective(params) do
      {:ok, _objective} ->
        conn
        |> put_flash(:info, "Objective created successfully.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Objective creation failed.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def update(conn, %{"project" => project_id, "id" => id, "objective" => objective_params}) do
    objective = Learning.get_objective!(id)
    project = Course.get_project_by_slug(conn.params["project"])
    params = Map.merge(objective_params, %{"project_id" => project.id})
    case Learning.update_objective(objective, params) do
      {:ok, objective} ->
        conn
        |> put_flash(:info, "Objective updated successfully.")
        |> redirect(to: Routes.objective_path(conn, :show, project_id, objective))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Objective update failed.")
        |> redirect(to: Routes.project_path(conn, :objectives, project_id))
    end
  end

  def delete(conn, %{"project" => project_id, "id" => id}) do
    objective = Learning.get_objective!(id)
    {:ok, _objective} = Learning.delete_objective(objective)

    conn
    |> put_flash(:info, "Objective deleted successfully.")
    |> redirect(to: Routes.project_path(conn, :objectives, project_id))
  end

  defp fetch_project(conn, _) do
    case Course.get_project_by_slug(conn.params["project"]) do
      nil ->
        conn
        |> put_flash(:info, "That project does not exist")
        |> redirect(to: Routes.workspace_path(conn, :projects))
        |> halt()
      project -> conn
                 |> assign(:project, project)
    end
  end

  defp authorize_project(conn, _) do
    if Accounts.can_access?(conn.assigns[:current_author], conn.assigns[:project]) do
      conn
    else
      conn
      |> put_flash(:info, "You don't have access to that project")
      |> redirect(to: Routes.workspace_path(conn, :projects))
      |> halt()
    end
  end

end

defmodule OliWeb.ObjectiveController do
  use OliWeb, :controller
  require Logger
  alias Oli.Course
  alias Oli.Learning
  alias Oli.Learning.Objective

#  def new(conn, %{"project" => project_id}) do
#    changeset = Learning.change_objective(%Objective{})
#    render conn, "new.html", changeset: changeset, title: "Objectives"
#  end

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

  def show(conn, %{"project" => project_id, "id" => id}) do
    objective = Learning.get_objective!(id)
    render conn, "show.html", objective: objective, title: "Objectives"
  end

  def edit(conn, %{"project" => project_id, "id" => id}) do
    objective = Learning.get_objective!(id)
    changeset = Learning.change_objective(objective)
    render(conn, "edit.html", objective: objective, changeset: changeset, title: "Objectives")
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
        render(conn, "edit.html", objective: objective, changeset: changeset, title: "Objectives")
    end
  end

  def delete(conn, %{"project" => project_id, "id" => id}) do
    objective = Learning.get_objective!(id)
    {:ok, _objective} = Learning.delete_objective(objective)

    conn
    |> put_flash(:info, "Objective deleted successfully.")
    |> redirect(to: Routes.project_path(conn, :objectives, project_id))
  end

end

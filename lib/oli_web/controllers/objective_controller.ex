defmodule OliWeb.ObjectiveController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  alias Oli.Authoring.Editing.ObjectiveEditor

  plug :fetch_project when action in [:create, :update, :delete]
  plug :authorize_project when action in [:create, :update, :delete]

  def create(conn, %{"project_id" => _, "revision" => objective_params}) do
    project = conn.assigns.project
    author = conn.assigns[:current_author]
    container_slug = Map.get(objective_params, "parent_slug")

    with_atom_keys = Map.keys(objective_params)
    |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_atom(k), Map.get(objective_params, k)) end)

    case ObjectiveEditor.add_new(with_atom_keys, author, project, container_slug) do
      {:ok, _} -> conn
        |> put_flash(:info, "Objective created successfully.")
        |> put_req_header("x-status", "success")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
      _error -> conn
        |> put_flash(:error, "Objective creation failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
    end

  end


  def create(conn, %{"project_id" => _, "title" => title}) do

    project = conn.assigns.project
    author = conn.assigns[:current_author]

    case ObjectiveEditor.add_new(%{title: title}, author, project, nil) do
      {:ok, _} -> conn
        |> put_flash(:info, "Objective created successfully.")
        |> put_req_header("x-status", "success")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
      _error -> conn
        |> put_flash(:error, "Objective creation failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
    end

  end


  def update(conn, %{"project_id" => _project_id, "objective_slug" => objective_slug, "revision" => objective_params}) do

    project = conn.assigns.project
    author = conn.assigns[:current_author]

    with_atom_keys = Map.keys(objective_params)
    |> Enum.reduce(%{}, fn k, m -> Map.put(m, String.to_atom(k), Map.get(objective_params, k)) end)

    case ObjectiveEditor.edit(objective_slug, with_atom_keys, author, project) do
      {:ok, _} -> conn
        |> put_flash(:info, "Objective updated successfully.")
        |> put_req_header("x-status", "success")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
      _error -> conn
        |> put_flash(:error, "Objective update failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
    end

  end

  def delete(conn, %{"project_id" => _, "objective_slug" => objective_slug}) do

    project = conn.assigns.project
    author = conn.assigns[:current_author]

    case ObjectiveEditor.edit(objective_slug, %{ deleted: true }, author, project) do
      {:ok, _} -> conn
        |> put_flash(:info, "Objective deleted successfully.")
        |> put_req_header("x-status", "success")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
      _error -> conn
        |> put_flash(:error, "Objective delete failed.")
        |> put_req_header("x-status", "failed")
        |> redirect(to: Routes.project_path(conn, :objectives, project.slug))
    end

  end
end

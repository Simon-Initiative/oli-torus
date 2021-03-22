defmodule OliWeb.ProjectActivityController do
  use OliWeb, :controller

  alias Oli.Activities

  def enable_activity(conn, %{"project_id" => project_id, "activity_slug" => activity_slug}) do
     case Activities.enable_activity_in_project(project_id, activity_slug) do
      {:ok, _} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't enable activity for the project. #{message}")
        |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

  def disable_activity(conn, %{"project_id" => project_id, "activity_slug" => activity_slug}) do
    case Activities.disable_activity_in_project(project_id, activity_slug) do
      {:ok, _} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't disable activity from the project. #{message}")
        |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

end

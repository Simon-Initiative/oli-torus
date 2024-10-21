defmodule OliWeb.ProjectActivityController do
  use OliWeb, :controller

  alias Oli.Activities

  def enable_activity(conn, %{"project_id" => project_id, "activity_slug" => activity_slug}) do
    case Activities.enable_activity_in_project(project_id, activity_slug) do
      {:ok, _} ->
        redirect(conn, to: ~p"/workspaces/course_author/#{project_id}/overview")

      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't enable activity for the project. #{message}")
        |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
    end
  end

  def disable_activity(conn, %{"project_id" => project_id, "activity_slug" => activity_slug}) do
    case Activities.disable_activity_in_project(project_id, activity_slug) do
      {:ok, _} ->
        redirect(conn, to: ~p"/workspaces/course_author/#{project_id}/overview")

      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't disable activity from the project. #{message}")
        |> redirect(to: ~p"/workspaces/course_author/#{project_id}/overview")
    end
  end
end

defmodule OliWeb.ExperimentController do
  use OliWeb, :controller

  require Logger

  def experiment_download(conn, %{"project_id" => project_slug}) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil -> error(conn, 404, "Project not found")
      _project -> disabled_export(conn, project_slug, "experiment")
    end
  end

  def segment_download(conn, %{"project_id" => project_slug}) do
    case Oli.Authoring.Course.get_project_by_slug(project_slug) do
      nil -> error(conn, 404, "Project not found")
      _project -> disabled_export(conn, project_slug, "segment")
    end
  end

  defp disabled_export(conn, project_slug, export_type) do
    Logger.warning("Disabled UpGrade #{export_type} export requested for project #{project_slug}")

    error(conn, 410, "UpGrade experiment JSON export has been removed")
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

defmodule OliWeb.ObjectivesCsvController do
  @moduledoc "Downloads the filtered learning-objective coverage map for an authoring project."

  use OliWeb, :controller

  alias Oli.Authoring.ObjectiveCoverage.CsvExport

  @spec download(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def download(conn, params) do
    project = conn.assigns.project

    case CsvExport.generate(project, params) do
      {:ok, contents} ->
        conn
        |> put_resp_header("cache-control", "private, no-store")
        |> put_resp_header("content-type", "text/csv")
        |> send_download({:binary, contents},
          filename: "#{project.slug}_learning_objectives.csv"
        )

      {:error, _reason} ->
        send_resp(conn, :not_found, "Learning objective data is unavailable")
    end
  end
end

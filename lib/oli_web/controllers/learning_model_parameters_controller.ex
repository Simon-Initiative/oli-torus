defmodule OliWeb.LearningModelParametersController do
  @moduledoc "Streams project parameter CSV downloads without buffering the entire file."

  use OliWeb, :controller

  alias Oli.Authoring.Course
  alias Oli.LearningModel.ParameterCsv

  @doc "Streams the authorized project’s current LKT-AOA parameters as a CSV attachment."
  def download(conn, %{"project_slug" => slug}) do
    with %{} = project <- Course.get_project_by_slug(slug),
         :ok <- ParameterCsv.authorize(project, conn.assigns.current_author) do
      conn =
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=learning-model-parameters.csv"
        )
        |> send_chunked(200)

      {:ok, conn} =
        ParameterCsv.export(project, conn.assigns.current_author, &stream_download(conn, &1))

      conn
    else
      nil -> send_resp(conn, 404, "Project not found")
      {:error, _} -> send_resp(conn, 403, "Forbidden")
    end
  end

  defp stream_download(conn, lines) do
    lines
    |> Stream.chunk_every(100)
    |> Enum.reduce_while(conn, fn batch, conn ->
      case chunk(conn, batch) do
        {:ok, conn} -> {:cont, conn}
        {:error, _} -> {:halt, conn}
      end
    end)
  end
end

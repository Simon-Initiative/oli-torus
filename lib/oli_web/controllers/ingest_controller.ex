defmodule OliWeb.IngestController do
  use OliWeb, :controller

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html", title: "Ingest")
  end

  def upload(conn, %{"upload" => upload}) do

    author = conn.assigns[:current_author]

    path_upload = upload["digest"]

    case Oli.Authoring.Ingest.ingest(path_upload.path, author) do
      {:ok, project} -> redirect(conn, to: Routes.project_path(conn, :overview, project))
      _ -> render(conn, "error.html", title: "Ingest")
    end

  end


end

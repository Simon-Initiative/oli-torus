defmodule OliWeb.IngestController do
  use OliWeb, :controller

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_ingest_page(conn, "index.html", title: "Ingest")
  end

  def upload(conn, %{"upload" => upload}) do
    author = conn.assigns[:current_author]

    path_upload = upload["digest"]

    case Oli.Interop.Ingest.ingest(path_upload.path, author) do
      {:ok, project} -> redirect(conn, to: Routes.project_path(conn, :overview, project))
      {:error, error} -> render_ingest_page(conn, "error.html", title: "Ingest", error: error)
    end
  end

  defp render_ingest_page(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :ingest))
  end
end

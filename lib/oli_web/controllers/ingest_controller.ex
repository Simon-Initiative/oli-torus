defmodule OliWeb.IngestController do
  use OliWeb, :controller

  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Interop.Ingest

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_ingest_page(conn)
  end

  def upload(conn, %{"upload" => upload}) do
    author = conn.assigns[:current_author]

    path_upload = upload["digest"]

    case Ingest.ingest(path_upload.path, author) do
      {:ok, project} -> redirect(conn, to: Routes.project_path(conn, :overview, project))
      error -> render_ingest_page(conn, error: error)
    end
  end

  defp render_ingest_page(conn, keywords \\ []) do
    render(
      conn,
      "index.html",
      Keyword.merge([active: :ingest, title: "Ingest", breadcrumbs: set_breadcrumbs()], keywords)
    )
  end

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Ingest Course Project",
          link: Routes.ingest_path(OliWeb.Endpoint, :index)
        })
      ]
  end
end

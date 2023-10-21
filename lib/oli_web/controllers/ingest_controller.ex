defmodule OliWeb.IngestController do
  use OliWeb, :controller

  require Logger

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_ingest_page(conn, :index, title: "Ingest")
  end

  def upload(conn, params) do
    author = conn.assigns[:current_author]

    upload = params["upload"]

    if not is_nil(upload) do
      if !File.exists?("_digests") do
        File.mkdir!("_digests")
      end

      File.cp(upload["digest"].path, "_digests/#{author.id}-digest.zip")

      conn
      |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2))
    else
      conn
      |> put_flash(:error, "A valid file must be attached")
      |> redirect(to: Routes.ingest_path(conn, :index))
    end
  end

  defp render_ingest_page(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :ingest))
  end

  def index_csv(conn, _params) do
    render_ingest_page_csv(conn, :index_csv, title: "Import")
  end

  def upload_csv(conn, %{"project_slug" => project_slug} = params) do
    author = conn.assigns[:current_author]

    upload = params["upload_csv"]

    if not is_nil(upload) do
      if !File.exists?("_imports") do
        File.mkdir!("_imports")
      end

      File.cp(upload["digest"].path, "_imports/#{author.id}-import.csv")

      conn
      |> redirect(
        to: Routes.live_path(OliWeb.Endpoint, OliWeb.Import.CSVImportView, project_slug)
      )
    else
      conn
      |> put_flash(:error, "A valid file must be attached")
      |> redirect(to: Routes.ingest_path(conn, :index_csv))
    end
  end

  defp render_ingest_page_csv(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :ingest))
  end
end

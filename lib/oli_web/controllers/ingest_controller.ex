defmodule OliWeb.IngestController do
  use OliWeb, :controller

  require Logger

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_ingest_page(conn, "index.html", title: "Ingest")
  end

  def upload(conn, %{"upload" => upload}) do
    author = conn.assigns[:current_author]

    if !File.exists?("_digests") do
      File.mkdir!("_digests")
    end

    File.cp(upload["digest"].path, "_digests/#{author.id}-digest.zip")

    conn
    |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2))
  end

  defp render_ingest_page(conn, page, keywords) do
    render(conn, page, Keyword.put_new(keywords, :active, :ingest))
  end
end

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

  def index_csv(conn, %{"project_slug" => project_slug}) do
    render_ingest_page_csv(conn, :index_csv, title: "Import", project_slug: project_slug)
  end

  def download_current(conn, %{"project_slug" => project_slug}) do
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    rows =
      Oli.Publishing.AuthoringResolver.full_hierarchy(project_slug)
      |> Oli.Delivery.Hierarchy.flatten_hierarchy()
      |> Enum.map(fn %{
                       numbering: %{
                         index: index,
                         level: level
                       },
                       revision: %{
                         resource_type_id: type_id,
                         title: title,
                         slug: slug,
                         poster_image: poster_image,
                         intro_content: intro_content,
                         intro_video: intro_video,
                         duration_minutes: duration_minutes,
                         purpose: purpose
                       }
                     } ->
        case type_id do
          ^container_type_id ->
            c =
              case level do
                0 -> "Root Resource"
                1 -> "Unit #{index}"
                _ -> "Module #{index}"
              end

            [
              c,
              title,
              slug,
              duration_minutes |> v,
              poster_image |> v,
              intro_video |> v,
              intro_content |> m
            ]

          ^page_type_id ->
            page_type =
              case purpose do
                :foundation -> "foundation"
                _ -> "exploration"
              end

            [
              page_type,
              title,
              slug,
              duration_minutes |> v,
              poster_image |> v,
              intro_video |> v,
              intro_content |> m
            ]
        end
      end)

    headers = [
      "type",
      "title",
      "slug",
      "duration_minutes",
      "poster_image",
      "intro_video",
      "intro_content"
    ]

    content =
      [headers | rows]
      |> CSV.encode()
      |> Enum.to_list()

    conn
    |> send_download({:binary, content},
      filename: "current_attrs_#{project_slug}.csv"
    )
  end

  defp m(%{"children" => children}) do
    Enum.map(children, fn c ->
      Enum.map(c["children"], fn t ->
        if t["bold"] do
          "**#{t["text"]}**"
        else
          t["text"]
        end
      end)
    end)
    |> Enum.join("|")
  end

  defp m(_), do: ""

  defp v(nil), do: ""
  defp v(v) when is_binary(v), do: v
  defp v(v) when is_map(v), do: v
  defp v(v), do: Integer.to_string(v)

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

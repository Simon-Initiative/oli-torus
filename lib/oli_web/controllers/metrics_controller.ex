defmodule OliWeb.MetricsController do
  use OliWeb, :controller
  require Logger

  @doc """
  Endpoint that triggers download of a container specific progress report.
  """
  def download_container_progress(conn, %{"section_slug" => slug, "container_id" => container_id} = params) do

    {container_id, _} = Integer.parse(container_id)

    case Oli.Delivery.Sections.get_section_by_slug(slug) do
      nil ->
        OliWeb.StaticPageController.not_found(conn, params)

      section ->

        contents = Oli.Delivery.Metrics.progress_datatable_for(section.id, container_id)
        |> Oli.Analytics.DataTables.DataTable.to_csv_content()

        conn
        |> send_download({:binary, contents},
          filename: "progress_#{slug}_#{container_id}.csv"
        )

    end

  end

end

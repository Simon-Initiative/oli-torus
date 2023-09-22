defmodule Oli.Analytics.DatashopExportWorker do
  use Oban.Worker,
    queue: :datashop_export,
    priority: 3,
    max_attempts: 1

  require Logger

  alias Oli.Utils
  alias Oli.Authoring.Broadcaster
  alias Oli.Analytics.Datashop
  alias Oli.Authoring.Course

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_slug" => project_slug} = _args}) do
    try do
      {full_upload_url, timestamp} = generate(project_slug)

      # notify subscribers that the export is available
      Broadcaster.broadcast_datashop_export_status(
        project_slug,
        {:available, full_upload_url, timestamp}
      )
    rescue
      e ->
        # notify subscribers that the export failed
        Broadcaster.broadcast_datashop_export_status(
          project_slug,
          {:error, e}
        )

        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        reraise e, __STACKTRACE__
    end

    :ok
  end

  def generate(project_slug) do
    project = Course.get_project_by_slug(project_slug)

    datashop_xml = Datashop.export(project.id)

    timestamp = DateTime.utc_now()
    random_string = Oli.Utils.random_string(16)

    {:ok, file_timestamp} = timestamp |> Timex.format("%Y-%m-%d-%H%M%S", :strftime)

    filename = "datashop_#{project_slug}_#{file_timestamp}.xml"

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    datashop_snapshot_path = Path.join(["datashop", project_slug, random_string, filename])

    {:ok, full_upload_url} =
      Utils.S3Storage.put(bucket_name, datashop_snapshot_path, datashop_xml)

    # update the project's last_exported_at timestamp
    Course.update_project_latest_datashop_snapshot_url(project_slug, full_upload_url, timestamp)

    {full_upload_url, timestamp}
  end
end

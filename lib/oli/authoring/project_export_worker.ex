defmodule Oli.Authoring.ProjectExportWorker do
  use Oban.Worker,
    queue: :project_export,
    priority: 3,
    max_attempts: 1

  require Logger

  alias Oli.Utils
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_slug" => project_slug} = _args}) do
    try do
      {full_upload_url, timestamp} = export(project_slug)

      # notify subscribers that the export is available
      Broadcaster.broadcast_project_export_status(
        project_slug,
        {:available, full_upload_url, timestamp}
      )
    rescue
      e ->
        # notify subscribers that the export failed
        Broadcaster.broadcast_project_export_status(
          project_slug,
          {:error, e}
        )

        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        reraise e, __STACKTRACE__
    end

    :ok
  end

  def export(project_slug) do
    timestamp = DateTime.utc_now()

    project = Course.get_project_by_slug(project_slug)

    export_zip_content = Oli.Interop.Export.export(project)

    random_string = Oli.Utils.random_string(16)

    filename = "export_#{project_slug}.zip"

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    project_export_path = Path.join(["exports", project_slug, random_string, filename])

    {:ok, full_upload_url} =
      Utils.S3Storage.put(bucket_name, project_export_path, export_zip_content)

    # update the project's last_exported_at timestamp
    Course.update_project_latest_export_url(project_slug, full_upload_url, timestamp)

    {full_upload_url, timestamp}
  end
end

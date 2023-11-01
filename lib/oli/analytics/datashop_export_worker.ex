defmodule Oli.Analytics.DatashopExportWorker do
  use Oban.Worker,
    queue: :datashop_export,
    priority: 3,
    max_attempts: 1

  require Logger

  # @upload_chunk_size 100

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

  defp build_filename(project) do
    timestamp = DateTime.utc_now()
    random_string = Oli.Utils.random_string(16)

    {:ok, file_timestamp} = timestamp |> Timex.format("%Y-%m-%d-%H%M%S", :strftime)

    filename = "datashop_#{project.slug}_#{file_timestamp}.xml"

    Path.join(["datashop", project.slug, random_string, filename])
  end

  def generate(project_slug) do
    project = Course.get_project_by_slug(project_slug)

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    datashop_snapshot_path = build_filename(project)

    first_chunk = Datashop.content_prefix()
    last_chunk = Datashop.content_suffix()

    total = Datashop.count(project.id)

    {:ok, result} = Oli.Repo.transaction(fn ->

      Oli.Utils.use_tmp(fn tmp_dir ->

        temp_file_name = Path.join([tmp_dir, "datashop_#{project_slug}_#{Oli.Utils.random_string(16)}.xml"])

        Datashop.build_context(project.id)
        |> Datashop.content_stream()
        |> Stream.with_index(1)
        |> Stream.map(fn {chunk, index} ->

          chunk = chunk |> XmlBuilder.generate()

          chunk = if index == 1 do
            first_chunk <> chunk
          else
            chunk
          end

          chunk = if index == total do
            chunk <> last_chunk
          else
            chunk
          end

          chunk

        end)
        |> Stream.into(File.stream!(temp_file_name))
        |> Stream.run()

        {:ok, full_upload_url} = Oli.Utils.S3Storage.stream_file(bucket_name, datashop_snapshot_path, temp_file_name)

        timestamp = DateTime.utc_now()

        # update the project's last_exported_at timestamp
        Course.update_project_latest_datashop_snapshot_url(project_slug, full_upload_url, timestamp)

        {full_upload_url, timestamp}


      end)


    end)

    result
  end
end

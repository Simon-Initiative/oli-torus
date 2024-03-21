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
  def perform(%Oban.Job{
        args: %{"project_slug" => project_slug, "section_ids" => section_ids} = _args
      }) do
    try do
      {full_upload_url, timestamp} = generate(project_slug, section_ids)

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

  def generate(project_slug, section_ids) do
    Logger.info("Generating datashop export for project #{project_slug}")

    project = Course.get_project_by_slug(project_slug)

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    datashop_snapshot_path = build_filename(project)

    {:ok, result} =
      Oli.Repo.transaction(
        fn ->
          Oli.Utils.use_tmp(fn tmp_dir ->
            temp_file_name =
              Path.join([tmp_dir, "datashop_#{project_slug}_#{Oli.Utils.random_string(16)}.xml"])

            write_to_file(temp_file_name, project, section_ids)

            Logger.info("Wrote Datashop file #{temp_file_name} for project #{project_slug}")

            {:ok, full_upload_url} =
              Oli.Utils.S3Storage.stream_file(bucket_name, datashop_snapshot_path, temp_file_name)

            Logger.info("Uploaded Datashop file #{full_upload_url} for project #{project_slug}")

            timestamp = DateTime.utc_now()

            # update the project's last_exported_at timestamp
            Course.update_project_latest_datashop_snapshot_url(
              project_slug,
              full_upload_url,
              timestamp
            )

            {full_upload_url, timestamp}
          end)
        end,
        timeout: :infinity
      )

    result
  end

  defp write_to_file(temp_file_name, project, section_ids) do
    first_chunk = Datashop.content_prefix()
    last_chunk = Datashop.content_suffix()

    batch_size = Datashop.max_record_size()
    total = Datashop.count(section_ids)
    batch_count = ceil(total / batch_size)

    context = Datashop.build_context(project.id, section_ids)

    if batch_count != 0 do
      Enum.reduce(1..batch_count, 0, fn batch_index, offset ->
        # notify subscribers that a new batch has started
        Broadcaster.broadcast_datashop_export_batch_started(
          project.slug,
          batch_index,
          batch_count
        )

        context
        |> Datashop.content_stream(offset, batch_size)
        |> Stream.with_index(offset + 1)
        |> Stream.map(fn {chunk, index} ->
          Logger.info(
            "Streaming chunk #{index} of #{total} chunks for Datashop export for project #{project.slug}"
          )

          chunk = XmlBuilder.generate(chunk)

          case index do
            1 -> first_chunk <> chunk
            ^total -> chunk <> last_chunk
            _ -> chunk
          end
        end)
        |> Stream.into(File.stream!(temp_file_name, [:append]))
        |> Stream.run()

        offset + batch_size
      end)
    end
  end
end

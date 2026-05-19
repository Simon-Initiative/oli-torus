defmodule Oli.Authoring.ProjectExportWorker do
  use Oban.Worker,
    queue: :project_export,
    priority: 3,
    max_attempts: 1

  @local_output_dir_env "PROJECT_EXPORT_LOCAL_OUTPUT_DIR"

  require Logger

  alias Oli.Utils
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project

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

    project_export_path = Path.join(["exports", project_slug, random_string, filename])

    full_upload_url =
      case local_output_dir() do
        nil ->
          upload_to_s3(project_export_path, export_zip_content)

        local_output_dir ->
          write_to_local_output(local_output_dir, project_export_path, export_zip_content)
      end

    # update the project's last_exported_at timestamp
    Course.update_project_latest_export_url(project_slug, full_upload_url, timestamp)

    {full_upload_url, timestamp}
  end

  defp local_output_dir do
    case System.get_env(@local_output_dir_env) do
      nil -> nil
      "" -> nil
      directory -> Path.expand(directory)
    end
  end

  defp upload_to_s3(project_export_path, export_zip_content) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    {:ok, full_upload_url} =
      Utils.S3Storage.put(bucket_name, project_export_path, export_zip_content)

    full_upload_url
  end

  defp write_to_local_output(local_output_dir, project_export_path, export_zip_content) do
    file_path =
      Path.join(local_output_dir, project_export_path)
      |> Path.expand()

    file_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(file_path, export_zip_content)

    Logger.info("Project export written to local file #{file_path}")

    "file://#{file_path}"
  end

  @doc """
  Generates a project export for the given project if one is not already in progress
  """
  def generate_project_export(project) do
    case project_export_status(project) do
      {:in_progress} ->
        {:error, "Project export is already in progress"}

      _ ->
        %{project_slug: project.slug}
        |> Oli.Authoring.ProjectExportWorker.new()
        |> Oban.insert()
    end
  end

  def project_export_status(project) do
    if Course.export_in_progress?(project.slug, "project_export") do
      # export is in progress
      {:in_progress}
    else
      case project do
        # export is created and completed
        %Project{
          latest_export_url: export_url,
          latest_export_timestamp: export_timestamp
        }
        when not is_nil(export_url) and not is_nil(export_timestamp) ->
          {:available, export_url, export_timestamp}

        # export has not been created yet
        _ ->
          {:not_available}
      end
    end
  end
end

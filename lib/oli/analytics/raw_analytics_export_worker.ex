defmodule Oli.Analytics.RawAnalyticsExportWorker do
  use Oban.Worker,
    queue: :analytics_export,
    priority: 3

  alias Oli.Utils
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_slug" => project_slug} = _args}) do
    generate(project_slug)

    :ok
  end

  def generate(project_slug) do
    # create file and prepare for streaming data to it
    full_upload_url =
      Utils.use_tmp(fn tmp_dir ->
        write_raw_snapshot_data(project_slug, tmp_dir)
        write_derived_analytics_data(project_slug, tmp_dir)

        # zip.create requires charlists
        files =
          File.ls!(tmp_dir)
          |> Enum.map(&String.to_charlist/1)

        # zip up the files
        zip_filepath = Path.join([File.cwd!(), "analytics.zip"])
        {:ok, _filename} = :zip.create(zip_filepath, files, cwd: tmp_dir)

        bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
        analytics_snapshot_path = "analytics/#{project_slug}/analytics.zip"

        {:ok, full_upload_url} =
          Utils.S3Storage.stream_file(bucket_name, analytics_snapshot_path, zip_filepath)

        # cleanup zip file
        File.rm!(zip_filepath)

        full_upload_url
      end)

    # update the project's last_exported_at timestamp
    timestamp = DateTime.utc_now()
    Course.update_project_latest_analytics_snapshot_url(project_slug, full_upload_url, timestamp)

    # notify subscribers that the export is available
    Broadcaster.broadcast_analytics_export_status(
      project_slug,
      {:available, full_upload_url, timestamp}
    )
  end

  def write_raw_snapshot_data(project_slug, tmp_dir) do
    snapshots_title_row = [
      "Part Attempt ID",
      "Activity ID",
      "Page ID",
      "Objective ID",
      "Activity Title",
      "Activity Type",
      "Objective Title",
      "Attempt Number",
      "Graded?",
      "Correct?",
      "Activity Score",
      "Activity Out Of",
      "Hints Requested",
      "Part Score",
      "Part Out Of",
      "Student Response",
      "Feedback",
      "Activity Content",
      "Section Title",
      "Section Slug",
      "Date Created",
      "Student ID",
      "Activity Attempt ID",
      "Resource Attempt ID"
    ]

    tmp_filepath = Path.join([tmp_dir, "raw_analytics.tsv"])

    encoded_snapshots_title_row =
      [snapshots_title_row] |> CSV.encode(separator: ?\t) |> Enum.join("")

    # create file by writing the header row
    File.write!(
      tmp_filepath,
      encoded_snapshots_title_row
    )

    Oli.Analytics.Common.stream_project_raw_analytics_to_file!(project_slug, tmp_filepath)

    [tmp_filepath]
  end

  def write_derived_analytics_data(project_slug, tmp_filepath) do
    analytics_title_row = [
      "Resource Title",
      "Activity Title",
      "Number of Attempts",
      "Relative Difficulty",
      "Eventually Correct",
      "First Try Correct"
    ]

    [
      {"by_page.tsv", Oli.Analytics.ByPage.query_against_project_slug(project_slug)},
      {"by_activity.tsv", Oli.Analytics.ByActivity.query_against_project_slug(project_slug)},
      {"by_objective.tsv", Oli.Analytics.ByObjective.query_against_project_slug(project_slug)}
    ]
    |> Enum.map(fn {name, data} -> {name, [analytics_title_row | extract_analytics(data)]} end)
    |> Enum.map(fn {name, data} ->
      {name, data |> CSV.encode(separator: ?\t)}
    end)
    # |> Enum.map(fn {name, data} -> {name, Enum.join(data, "")} end)
    |> Enum.map(fn {name, data} ->
      filepath = Path.join([tmp_filepath, name])

      data
      |> Stream.into(File.stream!(filepath))
      |> Stream.run()

      filepath
    end)
  end

  def extract_analytics([
        %{
          slice: slice,
          number_of_attempts: number_of_attempts,
          relative_difficulty: relative_difficulty,
          eventually_correct: eventually_correct,
          first_try_correct: first_try_correct
        } = h
        | t
      ]) do
    [
      [
        slice.title,
        case Map.get(h, :activity) do
          nil -> slice.title
          %{title: nil} -> slice.title
          %{title: title} -> title
          _ -> slice.title
        end,
        if is_nil(number_of_attempts) do
          "No attempts"
        else
          Integer.to_string(number_of_attempts)
        end,
        if is_nil(relative_difficulty) do
          ""
        else
          Float.to_string(truncate(relative_difficulty))
        end,
        if is_nil(eventually_correct) do
          ""
        else
          format_percent(eventually_correct)
        end,
        if is_nil(first_try_correct) do
          ""
        else
          format_percent(first_try_correct)
        end
      ]
      | extract_analytics(t)
    ]
  end

  def extract_analytics([]), do: []

  def truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  def truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  def format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  def format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"
end

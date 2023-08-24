defmodule Oli.Analytics.DatashopExportWorker do
  use Oban.Worker,
    queue: :datashop_export,
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
    filenames =
      ["raw_analytics.tsv", "by_page.tsv", "by_activity.tsv", "by_objective.tsv"]
      # CSV Encoder expects charlists for filenames, not strings
      |> Enum.map(&String.to_charlist(&1))

    analytics =
      raw_snapshot_data(project_slug)
      |> Enum.concat(derived_analytics_data(project_slug))
      |> Enum.map(&CSV.encode(&1, separator: ?\t))
      |> Enum.map(&Enum.join(&1, ""))

    data = Enum.zip(filenames, analytics)
    # Convert to tuples of {filename, CSV table rows}
    |> Enum.map(&{elem(&1, 0), elem(&1, 1)})
    |> Utils.zip("analytics.zip")

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    datashop_snapshot_path = "analytics/#{project_slug}/analytics.zip"
    {:ok, full_upload_url} = Utils.S3Storage.put(bucket_name, datashop_snapshot_path, data)

    # update the project's last_exported_at timestamp
    timestamp = DateTime.utc_now()
    Course.update_project_latest_analytics_snapshot_url(project_slug, full_upload_url, timestamp)

    # notify subscribers that the export is available
    Broadcaster.broadcast_datashop_export_status(project_slug, {:available, full_upload_url, timestamp})
  end

  def raw_snapshot_data(project_slug) do
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

    snapshots = case Oli.Analytics.Common.snapshots_for_project(project_slug) do
      {:ok, snapshots} -> snapshots
      {:error, err} -> throw err
    end

    [
      [
        snapshots_title_row | snapshots
      ]
    ]
  end

  def derived_analytics_data(project_slug) do
    analytics_title_row = [
      "Resource Title",
      "Activity Title",
      "Number of Attempts",
      "Relative Difficulty",
      "Eventually Correct",
      "First Try Correct"
    ]

    [
      Oli.Analytics.ByPage.query_against_project_slug(project_slug),
      Oli.Analytics.ByActivity.query_against_project_slug(project_slug),
      Oli.Analytics.ByObjective.query_against_project_slug(project_slug)
    ]
    |> Enum.map(&[analytics_title_row | extract_analytics(&1)])
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

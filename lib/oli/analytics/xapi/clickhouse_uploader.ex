defmodule Oli.Analytics.XAPI.ClickHouseUploader do
  @moduledoc """
  Uploader implementation that sends xAPI statement bundles directly to ClickHouse.
  This is primarily intended for development environments where we want to bypass
  S3/Lambda ETL and send data directly to our OLAP store.
  """

  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.HTTP
  alias Oli.Analytics.AdvancedAnalytics

  require Logger

  @doc """
  Upload a statement bundle directly to ClickHouse.
  Parses the JSONL bundle and inserts the video events into the appropriate table.
  """
  def upload(%StatementBundle{body: body, category: category} = bundle) do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})

    case parse_and_insert_events(body, category, config) do
      {:ok, _count} = result ->
        Logger.debug("Successfully uploaded bundle #{bundle.bundle_id} to ClickHouse")
        result

      {:error, reason} = error ->
        Logger.error(
          "Failed to upload bundle #{bundle.bundle_id} to ClickHouse: #{inspect(reason)}"
        )

        error
    end
  end

  defp parse_and_insert_events(body, :video, config) do
    events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&is_video_event?/1)

    case events do
      [] -> {:ok, 0}
      events -> insert_video_events(events, config)
    end
  end

  defp parse_and_insert_events(_body, _category, _config) do
    # For now, only handle video events. Other categories will be no-ops.
    {:ok, 0}
  end

  defp is_video_event?(event) do
    # Check if this is a video-related xAPI statement
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/experienced" -> true
      "https://w3id.org/xapi/video/verbs/played" -> true
      "https://w3id.org/xapi/video/verbs/paused" -> true
      "https://w3id.org/xapi/video/verbs/seeked" -> true
      "https://w3id.org/xapi/video/verbs/completed" -> true
      _ -> false
    end
  end

  defp insert_video_events(events, config) do
    # Prepare the INSERT query
    query = build_video_insert_query()

    # Transform events to ClickHouse format
    values = Enum.map(events, &transform_video_event/1)

    # Build the complete INSERT statement
    insert_statement = query <> format_values(values)

    # Execute the query
    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} -> {:ok, length(events)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_video_insert_query() do
    video_events_table = AdvancedAnalytics.video_events_table()

    """
    INSERT INTO #{video_events_table} (
      event_id,
      timestamp,
      user_id,
      session_id,
      section_id,
      page_id,
      content_element_id,
      video_url,
      video_title,
      verb,
      video_time,
      video_length,
      video_progress,
      video_played_segments,
      video_play_time,
      video_seek_from,
      video_seek_to
    ) VALUES
    """
  end

  defp transform_video_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    # Convert ISO8601 timestamp to ClickHouse format (remove Z)
    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")

    event_id = get_in(event, ["id"]) || UUID.uuid4(:hex)

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"]
    session_id = extensions["http://oli.cmu.edu/extensions/session_id"]

    # Extract video-specific data from result extensions
    result_extensions = get_in(event, ["result", "extensions"]) || %{}

    video_url =
      result_extensions["video_url"] ||
        get_in(event, ["object", "id"])

    video_title =
      result_extensions["video_title"] ||
        get_in(event, ["object", "definition", "name", "en-US"])

    content_element_id = result_extensions["content_element_id"]
    video_time = result_extensions["video_time"]
    video_length = result_extensions["video_length"]
    video_progress = result_extensions["video_progress"]
    video_played_segments = result_extensions["video_played_segments"]
    video_play_time = result_extensions["video_play_time"]
    video_seek_from = result_extensions["video_seek_from"]
    video_seek_to = result_extensions["video_seek_to"]

    verb = get_in(event, ["verb", "id"])

    [
      quote_value(event_id),
      quote_value(timestamp),
      # Now guaranteed to be a string, never null
      quote_value(user_id),
      quote_value(session_id),
      # Now guaranteed to be a number, never null
      section_id,
      page_id,
      quote_value(content_element_id),
      quote_value(video_url),
      quote_value(video_title),
      quote_value(verb),
      video_time,
      video_length,
      video_progress,
      quote_value(video_played_segments),
      video_play_time,
      video_seek_from,
      video_seek_to
    ]
  end

  defp format_values(values_list) do
    values_list
    |> Enum.map(fn values ->
      "(" <> Enum.join(values, ", ") <> ")"
    end)
    |> Enum.join(", ")
  end

  defp quote_value(nil), do: "NULL"

  defp quote_value(value) when is_binary(value),
    do: "'" <> String.replace(value, "'", "''") <> "'"

  defp quote_value(value), do: to_string(value)

  defp execute_clickhouse_query(query, config) do
    url = "#{config.host}:#{config.port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    case HTTP.http().post(url, query, headers) do
      {:ok, %{status_code: 200} = response} ->
        {:ok, response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "ClickHouse query failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp ensure_tables_exist(config) do
    # Check if video_events table exists by running a simple query
    check_query = "SELECT 1 FROM video_events LIMIT 0"

    case execute_clickhouse_query(check_query, config) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        if String.contains?(to_string(reason), "doesn't exist") do
          Logger.warning("video_events table doesn't exist. Please run ClickHouse migrations.")
          Logger.warning("Run: mix clickhouse.migrate up")
          {:error, "video_events table doesn't exist. Run migrations first."}
        else
          {:error, reason}
        end
    end
  end
end

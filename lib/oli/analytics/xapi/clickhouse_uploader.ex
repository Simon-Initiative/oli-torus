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

    dbg(bundle)

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

  defp parse_and_insert_events(body, _category, config) do
    # Parse all events from the bundle
    parsed_events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    # Transform all events to the unified raw_events format
    unified_events =
      parsed_events
      |> Enum.map(&transform_to_raw_event/1)
      |> Enum.reject(&is_nil/1)

    # Insert all events into the unified table
    case insert_raw_events(unified_events, config) do
      {:ok, count} ->
        Logger.debug("Successfully processed #{count} events into raw_events table")
        {:ok, count}

      {:error, reason} ->
        Logger.error("Failed to insert events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp is_video_event?(event) do
    # Check if this is a video-related xAPI statement
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/experienced" ->
        true

      "https://w3id.org/xapi/video/verbs/played" ->
        true

      "https://w3id.org/xapi/video/verbs/paused" ->
        true

      "https://w3id.org/xapi/video/verbs/seeked" ->
        true

      "https://w3id.org/xapi/video/verbs/completed" ->
        true

      _ ->
        false
    end
  end

  defp is_activity_attempt_event?(event) do
    # Check for activity attempt specific patterns
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/answered" ->
        # Check if it has activity attempt context
        activity_attempt_guid = get_in(event, ["context", "extensions", "https://oli.cmu.edu/extensions/activity_attempt_guid"])
        not is_nil(activity_attempt_guid)

      _ ->
        false
    end
  end

  defp is_page_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/answered" ->
        # Check if it has page attempt context but no activity attempt context
        page_attempt_guid = get_in(event, ["context", "extensions", "https://oli.cmu.edu/extensions/page_attempt_guid"])
        activity_attempt_guid = get_in(event, ["context", "extensions", "https://oli.cmu.edu/extensions/activity_attempt_guid"])
        not is_nil(page_attempt_guid) and is_nil(activity_attempt_guid)

      _ ->
        false
    end
  end

  defp is_page_viewed_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/experienced" ->
        # Check if it's not a video event
        not is_video_event?(event)

      _ ->
        false
    end
  end

  defp is_part_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/answered" ->
        # Check if it has part attempt context
        part_attempt_guid = get_in(event, ["context", "extensions", "https://oli.cmu.edu/extensions/part_attempt_guid"])
        not is_nil(part_attempt_guid)

      _ ->
        false
    end
  end

  # Transform an xAPI event to the unified raw_events table format
  defp transform_to_raw_event(event) do
    cond do
      is_video_event?(event) -> transform_video_event(event)
      is_activity_attempt_event?(event) -> transform_activity_attempt_event(event)
      is_page_attempt_event?(event) -> transform_page_attempt_event(event)
      is_page_viewed_event?(event) -> transform_page_viewed_event(event)
      is_part_attempt_event?(event) -> transform_part_attempt_event(event)
      true -> nil
    end
  end

  defp transform_video_event(event) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = get_in(event, ["context", "extensions"]) || %{}

    %{
      event_id: event["id"],
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      host_name: get_in(context_extensions, ["https://oli.cmu.edu/extensions/host_name"]),
      section_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/section_id"]),
      project_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/project_id"]),
      publication_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/publication_id"]),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: "video",
      attempt_guid: get_in(context_extensions, ["https://oli.cmu.edu/extensions/attempt_guid"]),
      attempt_number: get_in(context_extensions, ["https://oli.cmu.edu/extensions/attempt_number"]),
      page_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_id"]),
      content_element_id: get_in(event, ["object", "id"]),
      video_url: get_in(extensions, ["https://w3id.org/xapi/video/extensions/session-id"]),
      video_title: get_in(event, ["object", "definition", "name", "en-US"]),
      video_time: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time"]),
      video_length: get_in(extensions, ["https://w3id.org/xapi/video/extensions/length"]),
      video_progress: get_in(extensions, ["https://w3id.org/xapi/video/extensions/progress"]),
      video_played_segments: get_in(extensions, ["https://w3id.org/xapi/video/extensions/played-segments"]),
      video_play_time: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time-from"]),
      video_seek_from: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time-from"]),
      video_seek_to: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time-to"])
    }
  end

  defp transform_activity_attempt_event(event) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = get_in(event, ["context", "extensions"]) || %{}
    result = event["result"] || %{}

    %{
      event_id: event["id"],
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      host_name: get_in(context_extensions, ["https://oli.cmu.edu/extensions/host_name"]),
      section_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/section_id"]),
      project_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/project_id"]),
      publication_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/publication_id"]),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: "activity_attempt",
      activity_attempt_guid: get_in(context_extensions, ["https://oli.cmu.edu/extensions/activity_attempt_guid"]),
      activity_attempt_number: get_in(context_extensions, ["https://oli.cmu.edu/extensions/activity_attempt_number"]),
      page_attempt_guid: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_attempt_guid"]),
      page_attempt_number: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_attempt_number"]),
      activity_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/activity_id"]),
      activity_revision_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/activity_revision_id"]),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: get_in(extensions, ["https://oli.cmu.edu/extensions/response"]),
      feedback: get_in(extensions, ["https://oli.cmu.edu/extensions/feedback"])
    }
  end

  defp transform_page_attempt_event(event) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = get_in(event, ["context", "extensions"]) || %{}
    result = event["result"] || %{}

    %{
      event_id: event["id"],
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      host_name: get_in(context_extensions, ["https://oli.cmu.edu/extensions/host_name"]),
      section_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/section_id"]),
      project_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/project_id"]),
      publication_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/publication_id"]),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: "page_attempt",
      page_attempt_guid: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_attempt_guid"]),
      page_attempt_number: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_attempt_number"]),
      page_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_id"]),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: get_in(extensions, ["https://oli.cmu.edu/extensions/response"]),
      feedback: get_in(extensions, ["https://oli.cmu.edu/extensions/feedback"])
    }
  end

  defp transform_page_viewed_event(event) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = get_in(event, ["context", "extensions"]) || %{}
    result = event["result"] || %{}

    %{
      event_id: event["id"],
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      host_name: get_in(context_extensions, ["https://oli.cmu.edu/extensions/host_name"]),
      section_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/section_id"]),
      project_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/project_id"]),
      publication_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/publication_id"]),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: "page_viewed",
      page_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/page_id"]),
      page_sub_type: get_in(extensions, ["https://oli.cmu.edu/extensions/page_sub_type"]),
      completion: result["completion"]
    }
  end

  defp transform_part_attempt_event(event) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = get_in(event, ["context", "extensions"]) || %{}
    result = event["result"] || %{}

    %{
      event_id: event["id"],
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      host_name: get_in(context_extensions, ["https://oli.cmu.edu/extensions/host_name"]),
      section_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/section_id"]),
      project_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/project_id"]),
      publication_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/publication_id"]),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: "part_attempt",
      part_attempt_guid: get_in(context_extensions, ["https://oli.cmu.edu/extensions/part_attempt_guid"]),
      part_attempt_number: get_in(context_extensions, ["https://oli.cmu.edu/extensions/part_attempt_number"]),
      activity_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/activity_id"]),
      part_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/part_id"]),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: get_in(extensions, ["https://oli.cmu.edu/extensions/response"]),
      feedback: get_in(extensions, ["https://oli.cmu.edu/extensions/feedback"]),
      hints_requested: get_in(extensions, ["https://oli.cmu.edu/extensions/hints_requested"]),
      attached_objectives: get_in(extensions, ["https://oli.cmu.edu/extensions/attached_objectives"]),
      session_id: get_in(context_extensions, ["https://oli.cmu.edu/extensions/session_id"])
    }
  end

  defp safe_extract_email(nil), do: nil
  defp safe_extract_email(mbox) when is_binary(mbox), do: String.replace(mbox, "mailto:", "")
  defp safe_extract_email(_), do: nil

  defp parse_timestamp(timestamp_str) when is_binary(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _offset} -> DateTime.to_unix(datetime, :microsecond) / 1_000_000
      _ -> nil
    end
  end

  defp parse_timestamp(_), do: nil

  defp insert_raw_events(events, config) do
    # Prepare the INSERT query
    query = build_raw_events_insert_query()

    # Build values for all events
    values =
      events
      |> Enum.map(&build_raw_event_values/1)
      |> Enum.join(",\n")

    # Combine query and values
    insert_statement = query <> values

    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} -> {:ok, length(events)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_raw_events_insert_query() do
    raw_events_table = AdvancedAnalytics.raw_events_table()

    """
    INSERT INTO #{raw_events_table} (
      event_id,
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      timestamp,
      event_type,
      attempt_guid,
      attempt_number,
      page_id,
      content_element_id,
      video_url,
      video_title,
      video_time,
      video_length,
      video_progress,
      video_played_segments,
      video_play_time,
      video_seek_from,
      video_seek_to,
      activity_attempt_guid,
      activity_attempt_number,
      page_attempt_guid,
      page_attempt_number,
      part_attempt_guid,
      part_attempt_number,
      activity_id,
      activity_revision_id,
      part_id,
      page_sub_type,
      score,
      out_of,
      scaled_score,
      success,
      completion,
      response,
      feedback,
      hints_requested,
      attached_objectives,
      session_id
    ) VALUES
    """
  end

  defp build_raw_event_values(event) do
    [
      escape_value(event[:event_id]),
      escape_value(event[:user_id]),
      escape_value(event[:host_name]),
      escape_value(event[:section_id]),
      escape_value(event[:project_id]),
      escape_value(event[:publication_id]),
      escape_value(event[:timestamp]),
      escape_value(event[:event_type]),
      escape_value(event[:attempt_guid]),
      escape_value(event[:attempt_number]),
      escape_value(event[:page_id]),
      escape_value(event[:content_element_id]),
      escape_value(event[:video_url]),
      escape_value(event[:video_title]),
      escape_value(event[:video_time]),
      escape_value(event[:video_length]),
      escape_value(event[:video_progress]),
      escape_value(event[:video_played_segments]),
      escape_value(event[:video_play_time]),
      escape_value(event[:video_seek_from]),
      escape_value(event[:video_seek_to]),
      escape_value(event[:activity_attempt_guid]),
      escape_value(event[:activity_attempt_number]),
      escape_value(event[:page_attempt_guid]),
      escape_value(event[:page_attempt_number]),
      escape_value(event[:part_attempt_guid]),
      escape_value(event[:part_attempt_number]),
      escape_value(event[:activity_id]),
      escape_value(event[:activity_revision_id]),
      escape_value(event[:part_id]),
      escape_value(event[:page_sub_type]),
      escape_value(event[:score]),
      escape_value(event[:out_of]),
      escape_value(event[:scaled_score]),
      escape_value(event[:success]),
      escape_value(event[:completion]),
      escape_value(event[:response]),
      escape_value(event[:feedback]),
      escape_value(event[:hints_requested]),
      escape_value(event[:attached_objectives]),
      escape_value(event[:session_id])
    ]
    |> Enum.join(", ")
    |> then(fn values -> "(#{values})" end)
  end

  defp escape_value(nil), do: "NULL"
  defp escape_value(value) when is_binary(value), do: "'#{String.replace(value, "'", "\\'")}'"
  defp escape_value(value) when is_number(value), do: to_string(value)
  defp escape_value(value) when is_boolean(value), do: if(value, do: "1", else: "0")
  defp escape_value(value), do: "'#{inspect(value)}'"

  defp execute_clickhouse_query(query, config) do
    # Include database in the URL path for ClickHouse HTTP interface
    url = "#{config.host}:#{config.port}/?database=#{config.database}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    case HTTP.http().post(url, query, headers) do
      {:ok, %{status_code: 200} = response} ->
        {:ok, response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Query failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end

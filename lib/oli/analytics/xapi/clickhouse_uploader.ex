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

  defp parse_and_insert_events(body, :activity_attempt, config) do
    events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&is_activity_attempt_event?/1)

    case events do
      [] -> {:ok, 0}
      events -> insert_activity_attempt_events(events, config)
    end
  end

  defp parse_and_insert_events(body, :page_attempt, config) do
    events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&is_page_attempt_event?/1)

    case events do
      [] -> {:ok, 0}
      events -> insert_page_attempt_events(events, config)
    end
  end

  defp parse_and_insert_events(body, :page_viewed, config) do
    events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&is_page_viewed_event?/1)

    case events do
      [] -> {:ok, 0}
      events -> insert_page_viewed_events(events, config)
    end
  end

  defp parse_and_insert_events(body, :part_attempt, config) do
    events =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&is_part_attempt_event?/1)

    case events do
      [] -> {:ok, 0}
      events -> insert_part_attempt_events(events, config)
    end
  end

  defp parse_and_insert_events(_body, category, _config) do
    # Unsupported category - no-op
    Logger.warning("Unsupported category for ClickHouse upload, skipping: #{inspect(category)}")
    {:ok, 0}
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
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/completed" ->
        case get_in(event, ["object", "definition", "type"]) do
          "http://oli.cmu.edu/extensions/activity_attempt" -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp is_page_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/completed" ->
        case get_in(event, ["object", "definition", "type"]) do
          "http://oli.cmu.edu/extensions/page_attempt" -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp is_page_viewed_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://id.tincanapi.com/verb/viewed" ->
        case get_in(event, ["object", "definition", "type"]) do
          "http://oli.cmu.edu/extensions/types/page" -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp is_part_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      "http://adlnet.gov/expapi/verbs/completed" ->
        case get_in(event, ["object", "definition", "type"]) do
          "http://adlnet.gov/expapi/activities/question" -> true
          _ -> false
        end

      _ ->
        false
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

  defp insert_activity_attempt_events(events, config) do
    query = build_activity_attempt_insert_query()
    values = Enum.map(events, &transform_activity_attempt_event/1)
    insert_statement = query <> format_values(values)

    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} -> {:ok, length(events)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_page_attempt_events(events, config) do
    query = build_page_attempt_insert_query()
    values = Enum.map(events, &transform_page_attempt_event/1)
    insert_statement = query <> format_values(values)

    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} -> {:ok, length(events)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_page_viewed_events(events, config) do
    query = build_page_viewed_insert_query()
    values = Enum.map(events, &transform_page_viewed_event/1)
    insert_statement = query <> format_values(values)

    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} -> {:ok, length(events)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_part_attempt_events(events, config) do
    query = build_part_attempt_insert_query()
    values = Enum.map(events, &transform_part_attempt_event/1)
    insert_statement = query <> format_values(values)

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
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      attempt_guid,
      attempt_number,
      page_id,
      content_element_id,
      timestamp,
      video_url,
      video_title,
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

  defp build_activity_attempt_insert_query() do
    activity_attempt_events_table = AdvancedAnalytics.activity_attempt_events_table()

    """
    INSERT INTO #{activity_attempt_events_table} (
      event_id,
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      activity_attempt_guid,
      activity_attempt_number,
      page_attempt_guid,
      page_attempt_number,
      page_id,
      activity_id,
      activity_revision_id,
      timestamp,
      score,
      out_of,
      scaled_score,
      success,
      completion
    ) VALUES
    """
  end

  defp build_page_attempt_insert_query() do
    page_attempt_events_table = AdvancedAnalytics.page_attempt_events_table()

    """
    INSERT INTO #{page_attempt_events_table} (
      event_id,
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      page_attempt_guid,
      page_attempt_number,
      page_id,
      timestamp,
      score,
      out_of,
      scaled_score,
      success,
      completion
    ) VALUES
    """
  end

  defp build_page_viewed_insert_query() do
    page_viewed_events_table = AdvancedAnalytics.page_viewed_events_table()

    """
    INSERT INTO #{page_viewed_events_table} (
      event_id,
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      page_attempt_guid,
      page_attempt_number,
      page_id,
      page_sub_type,
      timestamp,
      success,
      completion
    ) VALUES
    """
  end

  defp build_part_attempt_insert_query() do
    part_attempt_events_table = AdvancedAnalytics.part_attempt_events_table()

    """
    INSERT INTO #{part_attempt_events_table} (
      event_id,
      user_id,
      host_name,
      section_id,
      project_id,
      publication_id,
      part_attempt_guid,
      part_attempt_number,
      activity_attempt_guid,
      activity_attempt_number,
      page_attempt_guid,
      page_attempt_number,
      page_id,
      activity_id,
      activity_revision_id,
      part_id,
      timestamp,
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

  defp transform_video_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    # Convert ISO8601 timestamp to ClickHouse format (remove Z)
    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")

    event_id = get_in(event, ["id"]) || Ecto.UUID.generate()

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    project_id = extensions["http://oli.cmu.edu/extensions/project_id"] || 0
    publication_id = extensions["http://oli.cmu.edu/extensions/publication_id"] || 0
    attempt_guid = extensions["http://oli.cmu.edu/extensions/attempt_guid"] || ""
    attempt_number = extensions["http://oli.cmu.edu/extensions/attempt_number"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"]
    host_name = extensions["http://oli.cmu.edu/extensions/host_name"] || ""

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

    [
      quote_value(event_id),
      quote_value(user_id),
      quote_value(host_name),
      section_id,
      project_id,
      publication_id,
      quote_value(attempt_guid),
      attempt_number,
      page_id,
      quote_value(content_element_id),
      quote_value(timestamp),
      quote_value(video_url),
      quote_value(video_title),
      video_time,
      video_length,
      video_progress,
      quote_value(video_played_segments),
      video_play_time,
      video_seek_from,
      video_seek_to
    ]
  end

  defp transform_activity_attempt_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")
    event_id = get_in(event, ["id"]) || Ecto.UUID.generate()

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    project_id = extensions["http://oli.cmu.edu/extensions/project_id"] || 0
    publication_id = extensions["http://oli.cmu.edu/extensions/publication_id"] || 0

    activity_attempt_guid =
      extensions["http://oli.cmu.edu/extensions/activity_attempt_guid"] || ""

    activity_attempt_number =
      extensions["http://oli.cmu.edu/extensions/activity_attempt_number"] || 0

    page_attempt_guid = extensions["http://oli.cmu.edu/extensions/page_attempt_guid"] || ""
    page_attempt_number = extensions["http://oli.cmu.edu/extensions/page_attempt_number"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"] || 0
    activity_id = extensions["http://oli.cmu.edu/extensions/activity_id"] || 0
    activity_revision_id = extensions["http://oli.cmu.edu/extensions/activity_revision_id"] || 0
    host_name = extensions["http://oli.cmu.edu/extensions/host_name"] || ""

    # Extract result data
    result = get_in(event, ["result"]) || %{}
    score_data = result["score"] || %{}
    score = score_data["raw"]
    out_of = score_data["max"]
    scaled_score = score_data["scaled"]
    success = result["success"]
    completion = result["completion"]

    [
      quote_value(event_id),
      quote_value(user_id),
      quote_value(host_name),
      section_id,
      project_id,
      publication_id,
      quote_value(activity_attempt_guid),
      activity_attempt_number,
      quote_value(page_attempt_guid),
      page_attempt_number,
      page_id,
      activity_id,
      activity_revision_id,
      quote_value(timestamp),
      score,
      out_of,
      scaled_score,
      success,
      completion
    ]
  end

  defp transform_page_attempt_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")
    event_id = get_in(event, ["id"]) || Ecto.UUID.generate()

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    project_id = extensions["http://oli.cmu.edu/extensions/project_id"] || 0
    publication_id = extensions["http://oli.cmu.edu/extensions/publication_id"] || 0
    page_attempt_guid = extensions["http://oli.cmu.edu/extensions/page_attempt_guid"] || ""
    page_attempt_number = extensions["http://oli.cmu.edu/extensions/page_attempt_number"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"] || 0
    host_name = extensions["http://oli.cmu.edu/extensions/host_name"] || ""

    # Extract result data
    result = get_in(event, ["result"]) || %{}
    score_data = result["score"] || %{}
    score = score_data["raw"]
    out_of = score_data["max"]
    scaled_score = score_data["scaled"]
    success = result["success"]
    completion = result["completion"]

    [
      quote_value(event_id),
      quote_value(user_id),
      quote_value(host_name),
      section_id,
      project_id,
      publication_id,
      quote_value(page_attempt_guid),
      page_attempt_number,
      page_id,
      quote_value(timestamp),
      score,
      out_of,
      scaled_score,
      success,
      completion
    ]
  end

  defp transform_page_viewed_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")
    event_id = get_in(event, ["id"]) || Ecto.UUID.generate()

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    project_id = extensions["http://oli.cmu.edu/extensions/project_id"] || 0
    publication_id = extensions["http://oli.cmu.edu/extensions/publication_id"] || 0
    page_attempt_guid = extensions["http://oli.cmu.edu/extensions/page_attempt_guid"] || ""
    page_attempt_number = extensions["http://oli.cmu.edu/extensions/page_attempt_number"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"] || 0
    host_name = extensions["http://oli.cmu.edu/extensions/host_name"] || ""

    # Extract page sub type
    page_sub_type = get_in(event, ["object", "definition", "subType"])

    # Extract result data
    result = get_in(event, ["result"]) || %{}
    success = result["success"]
    completion = result["completion"]

    [
      quote_value(event_id),
      quote_value(user_id),
      quote_value(host_name),
      section_id,
      project_id,
      publication_id,
      quote_value(page_attempt_guid),
      page_attempt_number,
      page_id,
      quote_value(page_sub_type),
      quote_value(timestamp),
      success,
      completion
    ]
  end

  defp transform_part_attempt_event(event) do
    # Extract common fields
    user_id =
      get_in(event, ["actor", "account", "name"]) ||
        get_in(event, ["actor", "mbox"]) || ""

    raw_timestamp = get_in(event, ["timestamp"]) || DateTime.utc_now() |> DateTime.to_iso8601()
    timestamp = String.replace(raw_timestamp, "Z", "")
    event_id = get_in(event, ["id"]) || Ecto.UUID.generate()

    # Extract context extensions
    extensions = get_in(event, ["context", "extensions"]) || %{}
    section_id = extensions["http://oli.cmu.edu/extensions/section_id"] || 0
    project_id = extensions["http://oli.cmu.edu/extensions/project_id"] || 0
    publication_id = extensions["http://oli.cmu.edu/extensions/publication_id"] || 0
    part_attempt_guid = extensions["http://oli.cmu.edu/extensions/part_attempt_guid"] || ""
    part_attempt_number = extensions["http://oli.cmu.edu/extensions/part_attempt_number"] || 0

    activity_attempt_guid =
      extensions["http://oli.cmu.edu/extensions/activity_attempt_guid"] || ""

    activity_attempt_number =
      extensions["http://oli.cmu.edu/extensions/activity_attempt_number"] || 0

    page_attempt_guid = extensions["http://oli.cmu.edu/extensions/page_attempt_guid"] || ""
    page_attempt_number = extensions["http://oli.cmu.edu/extensions/page_attempt_number"] || 0
    page_id = extensions["http://oli.cmu.edu/extensions/page_id"] || 0
    activity_id = extensions["http://oli.cmu.edu/extensions/activity_id"] || 0
    activity_revision_id = extensions["http://oli.cmu.edu/extensions/activity_revision_id"] || 0
    part_id = extensions["http://oli.cmu.edu/extensions/part_id"] || ""
    hints_requested = extensions["http://oli.cmu.edu/extensions/hints_requested"] || 0
    attached_objectives = extensions["http://oli.cmu.edu/extensions/attached_objectives"]
    session_id = extensions["http://oli.cmu.edu/extensions/session_id"]
    host_name = extensions["http://oli.cmu.edu/extensions/host_name"] || ""

    # Extract result data
    result = get_in(event, ["result"]) || %{}
    score_data = result["score"] || %{}
    score = score_data["raw"]
    out_of = score_data["max"]
    scaled_score = score_data["scaled"]
    success = result["success"]
    completion = result["completion"]
    response = result["response"]

    # Extract feedback from result extensions
    result_extensions = result["extensions"] || %{}
    feedback = result_extensions["http://oli.cmu.edu/extensions/feedback"]

    # Convert attached_objectives to JSON string if it's a list
    attached_objectives_str =
      case attached_objectives do
        list when is_list(list) -> Jason.encode!(list)
        _ -> attached_objectives
      end

    [
      quote_value(event_id),
      quote_value(user_id),
      quote_value(host_name),
      section_id,
      project_id,
      publication_id,
      quote_value(part_attempt_guid),
      part_attempt_number,
      quote_value(activity_attempt_guid),
      activity_attempt_number,
      quote_value(page_attempt_guid),
      page_attempt_number,
      page_id,
      activity_id,
      activity_revision_id,
      quote_value(part_id),
      quote_value(timestamp),
      score,
      out_of,
      scaled_score,
      success,
      completion,
      quote_value(response),
      quote_value(feedback),
      hints_requested,
      quote_value(attached_objectives_str),
      quote_value(session_id)
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
end

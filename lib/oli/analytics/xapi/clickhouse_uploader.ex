defmodule Oli.Analytics.XAPI.ClickHouseUploader do
  @moduledoc """
  Uploader implementation that sends xAPI statement bundles directly to ClickHouse.
  This is primarily intended for development environments where we want to bypass
  S3/Lambda ETL and send data directly to our OLAP store.
  """

  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.HTTP
  alias Oli.Analytics.ClickhouseAnalytics

  require Logger

  @completed_attempt_verbs [
    "http://adlnet.gov/expapi/verbs/completed",
    "http://adlnet.gov/expapi/verbs/answered"
  ]

  @page_view_verbs [
    "http://id.tincanapi.com/verb/viewed",
    "http://adlnet.gov/expapi/verbs/experienced"
  ]

  @experiment_attributions_extension "http://oli.cmu.edu/extensions/experiment_attributions"

  @doc """
  Upload a statement bundle directly to ClickHouse.
  Parses the JSONL bundle and inserts the video events into the appropriate table.
  """
  def upload(%StatementBundle{body: body, category: category} = bundle) do
    raw_config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})

    config =
      raw_config
      |> Map.take([:host, :database])
      |> Map.put(:port, raw_config.http_port)
      |> Map.put(:user, raw_config.admin_user)
      |> Map.put(:password, raw_config.admin_password)

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
      |> Enum.map(fn raw_line -> {raw_line, Jason.decode!(raw_line)} end)

    # Transform all events to the unified raw_events format and fan out experiment
    # attribution arrays into attribution-level rows.
    unified_events =
      parsed_events
      |> Enum.map(&transform_to_raw_event/1)
      |> Enum.reject(&is_nil/1)

    experiment_attributions =
      parsed_events
      |> Enum.flat_map(&transform_experiment_attributions/1)

    # Insert all events into the unified table
    with {:ok, count} <- insert_raw_events(unified_events, config),
         {:ok, _attribution_count} <-
           insert_experiment_attributions(experiment_attributions, config) do
      Logger.debug("Successfully processed #{count} events into raw_events table")
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("Failed to insert events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp raw_event_base({raw_line, event}, event_type) do
    context_extensions = context_extensions(event)
    attributions = experiment_attributions(event)

    %{
      event_hash: event_hash(raw_line),
      user_id: safe_extract_email(get_in(event, ["actor", "mbox"])),
      home_page: get_in(event, ["actor", "account", "homePage"]),
      section_id: oli_extension(context_extensions, "section_id"),
      project_id: oli_extension(context_extensions, "project_id"),
      publication_id: oli_extension(context_extensions, "publication_id"),
      timestamp: parse_timestamp(event["timestamp"]),
      event_type: event_type,
      verb_id: get_in(event, ["verb", "id"]),
      has_experiment_attribution: attributions != [],
      experiment_attribution_count: length(attributions)
    }
  end

  defp insert_experiment_attributions([], _config), do: {:ok, 0}

  defp insert_experiment_attributions(attributions, config) do
    query = build_experiment_attributions_insert_query()

    values =
      attributions
      |> Enum.map(&build_experiment_attribution_values/1)
      |> Enum.join(",\n")

    insert_statement = query <> values

    case execute_clickhouse_query(insert_statement, config) do
      {:ok, _response} ->
        {:ok, length(attributions)}

      {:error, reason} ->
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
      verb when verb in @completed_attempt_verbs ->
        # Check if it has activity attempt context
        activity_attempt_guid =
          event |> context_extensions() |> oli_extension("activity_attempt_guid")

        not is_nil(activity_attempt_guid)

      _ ->
        false
    end
  end

  defp is_page_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      verb when verb in @completed_attempt_verbs ->
        # Check if it has page attempt context but no activity attempt context
        context_extensions = context_extensions(event)
        page_attempt_guid = oli_extension(context_extensions, "page_attempt_guid")
        activity_attempt_guid = oli_extension(context_extensions, "activity_attempt_guid")

        not is_nil(page_attempt_guid) and is_nil(activity_attempt_guid)

      _ ->
        false
    end
  end

  defp is_page_viewed_event?(event) do
    case get_in(event, ["verb", "id"]) do
      verb when verb in @page_view_verbs ->
        get_in(event, ["object", "definition", "type"]) ==
          "http://oli.cmu.edu/extensions/types/page"

      _ ->
        false
    end
  end

  defp is_part_attempt_event?(event) do
    case get_in(event, ["verb", "id"]) do
      verb when verb in @completed_attempt_verbs ->
        # Check if it has part attempt context
        part_attempt_guid = event |> context_extensions() |> oli_extension("part_attempt_guid")

        not is_nil(part_attempt_guid)

      _ ->
        false
    end
  end

  # Transform an xAPI event to the unified raw_events table format
  defp transform_to_raw_event({raw_line, event}) do
    cond do
      is_video_event?(event) -> transform_video_event({raw_line, event})
      is_activity_attempt_event?(event) -> transform_activity_attempt_event({raw_line, event})
      is_page_attempt_event?(event) -> transform_page_attempt_event({raw_line, event})
      is_page_viewed_event?(event) -> transform_page_viewed_event({raw_line, event})
      is_part_attempt_event?(event) -> transform_part_attempt_event({raw_line, event})
      true -> nil
    end
  end

  defp transform_video_event({raw_line, event}) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = context_extensions(event)
    object_extensions = get_in(event, ["object", "definition", "extensions"]) || %{}

    event
    |> then(&raw_event_base({raw_line, &1}, "video"))
    |> Map.merge(%{
      page_id: oli_extension(context_extensions, "page_id"),
      content_element_id:
        get_in(extensions, ["content_element_id"]) ||
          oli_extension(context_extensions, "content_element_id"),
      video_url: get_in(event, ["object", "id"]),
      video_time: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time"]),
      video_length:
        get_in(extensions, ["https://w3id.org/xapi/video/extensions/length"]) ||
          get_in(context_extensions, ["https://w3id.org/xapi/video/extensions/length"]) ||
          get_in(object_extensions, ["https://w3id.org/xapi/video/extensions/length"]),
      video_progress: get_in(extensions, ["https://w3id.org/xapi/video/extensions/progress"]),
      video_played_segments:
        get_in(extensions, ["https://w3id.org/xapi/video/extensions/played-segments"]),
      video_seek_from: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time-from"]),
      video_seek_to: get_in(extensions, ["https://w3id.org/xapi/video/extensions/time-to"]),
      activity_attempt_guid: oli_extension(context_extensions, "activity_attempt_guid"),
      activity_attempt_number: oli_extension(context_extensions, "activity_attempt_number"),
      page_attempt_guid: oli_extension(context_extensions, "page_attempt_guid"),
      page_attempt_number: oli_extension(context_extensions, "page_attempt_number"),
      part_attempt_guid: oli_extension(context_extensions, "part_attempt_guid"),
      part_attempt_number: oli_extension(context_extensions, "part_attempt_number"),
      activity_id: oli_extension(context_extensions, "activity_id"),
      activity_revision_id: oli_extension(context_extensions, "activity_revision_id"),
      part_id: oli_extension(context_extensions, "part_id")
    })
  end

  defp transform_activity_attempt_event({raw_line, event}) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = context_extensions(event)
    result = event["result"] || %{}

    event
    |> then(&raw_event_base({raw_line, &1}, "activity_attempt"))
    |> Map.merge(%{
      activity_attempt_guid: oli_extension(context_extensions, "activity_attempt_guid"),
      activity_attempt_number: oli_extension(context_extensions, "activity_attempt_number"),
      page_attempt_guid: oli_extension(context_extensions, "page_attempt_guid"),
      page_attempt_number: oli_extension(context_extensions, "page_attempt_number"),
      activity_id: oli_extension(context_extensions, "activity_id"),
      activity_revision_id: oli_extension(context_extensions, "activity_revision_id"),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: result["response"],
      feedback: oli_extension(extensions, "feedback")
    })
  end

  defp transform_page_attempt_event({raw_line, event}) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = context_extensions(event)
    result = event["result"] || %{}

    event
    |> then(&raw_event_base({raw_line, &1}, "page_attempt"))
    |> Map.merge(%{
      page_attempt_guid: oli_extension(context_extensions, "page_attempt_guid"),
      page_attempt_number: oli_extension(context_extensions, "page_attempt_number"),
      page_id: oli_extension(context_extensions, "page_id"),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: result["response"],
      feedback: oli_extension(extensions, "feedback")
    })
  end

  defp transform_page_viewed_event({raw_line, event}) do
    context_extensions = context_extensions(event)
    result = event["result"] || %{}

    event
    |> then(&raw_event_base({raw_line, &1}, "page_viewed"))
    |> Map.merge(%{
      page_id: oli_extension(context_extensions, "page_id"),
      page_sub_type: get_in(event, ["object", "definition", "subType"]),
      completion: result["completion"]
    })
  end

  defp transform_part_attempt_event({raw_line, event}) do
    extensions = get_in(event, ["result", "extensions"]) || %{}
    context_extensions = context_extensions(event)
    result = event["result"] || %{}

    event
    |> then(&raw_event_base({raw_line, &1}, "part_attempt"))
    |> Map.merge(%{
      part_attempt_guid: oli_extension(context_extensions, "part_attempt_guid"),
      part_attempt_number: oli_extension(context_extensions, "part_attempt_number"),
      activity_id: oli_extension(context_extensions, "activity_id"),
      part_id: oli_extension(context_extensions, "part_id"),
      score: get_in(result, ["score", "raw"]),
      out_of: get_in(result, ["score", "max"]),
      scaled_score: get_in(result, ["score", "scaled"]),
      success: result["success"],
      completion: result["completion"],
      response: result["response"],
      feedback: oli_extension(extensions, "feedback"),
      hints_requested: oli_extension(context_extensions, "hints_requested"),
      attached_objectives: oli_extension(context_extensions, "attached_objectives"),
      session_id: oli_extension(context_extensions, "session_id")
    })
  end

  defp transform_experiment_attributions({raw_line, event}) do
    result = event["result"] || %{}
    raw_hash = event_hash(raw_line)

    host_event_type =
      event
      |> then(&transform_to_raw_event({raw_line, &1}))
      |> case do
        nil -> "unknown"
        raw_event -> Map.get(raw_event, :event_type)
      end

    event
    |> experiment_attributions()
    |> Enum.map(fn attribution ->
      idempotency_key = Map.get(attribution, "idempotency_key")

      %{
        raw_event_hash: raw_hash,
        attribution_hash: attribution_hash(raw_hash, attribution),
        host_event_type: host_event_type,
        timestamp: parse_timestamp(event["timestamp"]),
        section_id: attribution_value(attribution, "section_id"),
        project_id: attribution_value(attribution, "project_id"),
        publication_id: attribution_value(attribution, "publication_id"),
        enrollment_id: attribution_value(attribution, "enrollment_id"),
        experiment_role: attribution_value(attribution, "role"),
        experiment_id: attribution_value(attribution, "experiment_id"),
        experiment_uuid: attribution_value(attribution, "experiment_uuid"),
        decision_point_id: attribution_value(attribution, "decision_point_id"),
        decision_point_key: attribution_value(attribution, "decision_point_key"),
        condition_id: attribution_value(attribution, "condition_id"),
        condition_code: attribution_value(attribution, "condition_code"),
        assignment_id: attribution_value(attribution, "assignment_id"),
        assignment_key: attribution_value(attribution, "assignment_key"),
        algorithm:
          attribution_value(attribution, "algorithm") ||
            attribution_value(attribution, "assigned_by_policy"),
        policy_version: attribution_value(attribution, "policy_version"),
        algorithm_version: attribution_value(attribution, "algorithm_version"),
        idempotency_key: idempotency_key,
        idempotency_key_hash: hash_key(idempotency_key),
        content_revision_id: attribution_value(attribution, "content_revision_id"),
        outcome_id: attribution_value(attribution, "outcome_id"),
        reward_id: attribution_value(attribution, "reward_id"),
        reward_value:
          attribution_value(attribution, "reward_value") ||
            get_in(result, ["score", "raw"]),
        reward_source: attribution_value(attribution, "reward_source"),
        policy_update_reason: attribution_value(attribution, "policy_update_reason"),
        previous_policy_state_hash: attribution_value(attribution, "previous_policy_state_hash"),
        next_policy_state_hash: attribution_value(attribution, "next_policy_state_hash")
      }
    end)
  end

  defp experiment_attributions(event) do
    event
    |> context_extensions()
    |> Map.get(@experiment_attributions_extension, [])
    |> case do
      attributions when is_list(attributions) -> Enum.filter(attributions, &is_map/1)
      _ -> []
    end
  end

  defp attribution_value(attribution, key), do: Map.get(attribution, key)

  defp context_extensions(event), do: get_in(event, ["context", "extensions"]) || %{}

  defp oli_extension(extensions, key) when is_map(extensions) and is_binary(key) do
    Enum.find_value(["http", "https"], fn scheme ->
      Map.get(extensions, "#{scheme}://oli.cmu.edu/extensions/#{key}")
    end)
  end

  defp oli_extension(_, _), do: nil

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

  defp hash_key(nil), do: nil

  defp hash_key(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
  end

  defp event_hash(raw_line) when is_binary(raw_line), do: hash_key(raw_line)

  defp attribution_hash(event_hash, attribution) do
    hash_key("#{event_hash}:#{canonical_json(attribution)}")
  end

  defp canonical_json(value) when is_map(value) do
    entries =
      value
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map(fn {key, value} ->
        "#{encode_canonical_json_value(to_string(key))}:#{canonical_json(value)}"
      end)
      |> Enum.join(",")

    "{#{entries}}"
  end

  defp canonical_json(value) when is_list(value) do
    value
    |> Enum.map(&canonical_json/1)
    |> Enum.join(",")
    |> then(fn entries -> "[#{entries}]" end)
  end

  defp canonical_json(value), do: encode_canonical_json_value(value)

  defp encode_canonical_json_value(value), do: Jason.encode!(value, escape: :unicode_safe)

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
    raw_events_table = ClickhouseAnalytics.raw_events_table()

    """
    INSERT INTO #{raw_events_table} (
      event_hash,
      user_id,
      home_page,
      section_id,
      project_id,
      publication_id,
      timestamp,
      event_type,
      verb_id,
      page_id,
      content_element_id,
      video_url,
      video_time,
      video_length,
      video_progress,
      video_played_segments,
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
      session_id,
      has_experiment_attribution,
      experiment_attribution_count
    ) VALUES
    """
  end

  defp build_raw_event_values(event) do
    [
      escape_value(event[:event_hash]),
      escape_value(event[:user_id]),
      escape_value(event[:home_page]),
      escape_value(event[:section_id]),
      escape_value(event[:project_id]),
      escape_value(event[:publication_id]),
      escape_value(event[:timestamp]),
      escape_value(event[:event_type]),
      escape_value(event[:verb_id]),
      escape_value(event[:page_id]),
      escape_value(event[:content_element_id]),
      escape_value(event[:video_url]),
      escape_value(event[:video_time]),
      escape_value(event[:video_length]),
      escape_value(event[:video_progress]),
      escape_value(event[:video_played_segments]),
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
      escape_value(event[:session_id]),
      escape_value(event[:has_experiment_attribution]),
      escape_value(event[:experiment_attribution_count])
    ]
    |> Enum.join(", ")
    |> then(fn values -> "(#{values})" end)
  end

  defp build_experiment_attributions_insert_query do
    """
    INSERT INTO #{experiment_attributions_table()} (
      raw_event_hash,
      attribution_hash,
      host_event_type,
      timestamp,
      section_id,
      project_id,
      publication_id,
      enrollment_id,
      experiment_role,
      experiment_id,
      experiment_uuid,
      decision_point_id,
      decision_point_key,
      condition_id,
      condition_code,
      assignment_id,
      assignment_key,
      algorithm,
      policy_version,
      algorithm_version,
      idempotency_key,
      idempotency_key_hash,
      content_revision_id,
      outcome_id,
      reward_id,
      reward_value,
      reward_source,
      policy_update_reason,
      previous_policy_state_hash,
      next_policy_state_hash
    ) VALUES
    """
  end

  defp build_experiment_attribution_values(attribution) do
    [
      escape_value(attribution[:raw_event_hash]),
      escape_value(attribution[:attribution_hash]),
      escape_value(attribution[:host_event_type]),
      escape_value(attribution[:timestamp]),
      escape_value(attribution[:section_id]),
      escape_value(attribution[:project_id]),
      escape_value(attribution[:publication_id]),
      escape_value(attribution[:enrollment_id]),
      escape_value(attribution[:experiment_role]),
      escape_value(attribution[:experiment_id]),
      escape_value(attribution[:experiment_uuid]),
      escape_value(attribution[:decision_point_id]),
      escape_value(attribution[:decision_point_key]),
      escape_value(attribution[:condition_id]),
      escape_value(attribution[:condition_code]),
      escape_value(attribution[:assignment_id]),
      escape_value(attribution[:assignment_key]),
      escape_value(attribution[:algorithm]),
      escape_value(attribution[:policy_version]),
      escape_value(attribution[:algorithm_version]),
      escape_value(attribution[:idempotency_key]),
      escape_value(attribution[:idempotency_key_hash]),
      escape_value(attribution[:content_revision_id]),
      escape_value(attribution[:outcome_id]),
      escape_value(attribution[:reward_id]),
      escape_value(attribution[:reward_value]),
      escape_value(attribution[:reward_source]),
      escape_value(attribution[:policy_update_reason]),
      escape_value(attribution[:previous_policy_state_hash]),
      escape_value(attribution[:next_policy_state_hash])
    ]
    |> Enum.join(", ")
    |> then(fn values -> "(#{values})" end)
  end

  defp experiment_attributions_table do
    ClickhouseAnalytics.raw_events_table()
    |> String.replace_suffix(".raw_events", ".experiment_attributions")
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

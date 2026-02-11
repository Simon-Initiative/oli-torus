defmodule Oli.Analytics.Backfill.QueryBuilder do
  @moduledoc """
  Builds ClickHouse SQL statements for bulk backfill operations.
  """

  alias Oli.Analytics.Backfill.BackfillRun

  @doc """
  Construct the INSERT ... SELECT statement used to ingest events from S3 into
  ClickHouse.
  """
  @spec insert_sql(BackfillRun.t(), map()) :: String.t()
  def insert_sql(%BackfillRun{} = run, aws_creds) do
    target_table = sanitize_target_table(run.target_table)
    s3_source = s3_source_clause(run, aws_creds)
    settings_clause = settings_clause(run.clickhouse_settings, aws_creds)

    """
    INSERT INTO #{target_table} (
        event_hash, event_version, source_file, source_etag, source_line, inserted_at,
        event_id, user_id, host_name, section_id, project_id, publication_id,
        timestamp, event_type, page_id,
        content_element_id, video_url, video_time, video_length,
        video_progress, video_played_segments, video_play_time, video_seek_from,
        video_seek_to, activity_attempt_guid, activity_attempt_number,
        page_attempt_guid, page_attempt_number, part_attempt_guid,
        part_attempt_number, activity_id, activity_revision_id, part_id,
        page_sub_type, score, out_of, scaled_score, success, completion,
        response, feedback, hints_requested, attached_objectives, session_id
    )
    SELECT
        cityHash64(json) AS event_hash,
        now64(3) AS event_version,
        _path AS source_file,
        _file AS source_etag,
        rowNumberInAllBlocks()
          - min(rowNumberInAllBlocks()) OVER (PARTITION BY _path)
          + 1 AS source_line,
        now() AS inserted_at,

        coalesce(JSON_VALUE(json, '$.event_id'), toString(generateUUIDv4())) AS event_id,

        coalesce(
          JSON_VALUE(json, '$.actor.account.name'),
          JSON_VALUE(json, '$.actor.mbox'),
          toString(JSONExtract(json, 'actor.account.name', 'Int64')),
          ''
        ) AS user_id,

        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/host_name"') AS host_name,
        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/section_id"')) AS section_id,
        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/project_id"')) AS project_id,
        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/publication_id"')) AS publication_id,

        parseDateTime64BestEffortOrNull(JSON_VALUE(json, '$.timestamp'), 3) AS timestamp,

        multiIf(
          JSON_VALUE(json, '$.verb.id') IN (
            'https://w3id.org/xapi/video/verbs/played',
            'https://w3id.org/xapi/video/verbs/paused',
            'https://w3id.org/xapi/video/verbs/seeked',
            'https://w3id.org/xapi/video/verbs/completed',
            'http://adlnet.gov/expapi/verbs/experienced'
          ), 'video',

          (JSON_VALUE(json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed')
            AND (JSON_VALUE(json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/activity_attempt'),
          'activity_attempt',

          (JSON_VALUE(json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed')
            AND (JSON_VALUE(json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/page_attempt'),
          'page_attempt',

          (JSON_VALUE(json, '$.verb.id') = 'http://id.tincanapi.com/verb/viewed')
            AND (JSON_VALUE(json, '$.object.definition.type') = 'http://oli.cmu.edu/extensions/types/page'),
          'page_viewed',

          (JSON_VALUE(json, '$.verb.id') = 'http://adlnet.gov/expapi/verbs/completed')
            AND (JSON_VALUE(json, '$.object.definition.type') = 'http://adlnet.gov/expapi/activities/question'),
          'part_attempt',

          'unknown'
        ) AS event_type,

        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/page_id"')) AS page_id,

        coalesce(
          JSON_VALUE(json, '$.result.extensions.content_element_id'),
          JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/content_element_id"'),
          NULL
        ) AS content_element_id,
        multiIf(
          JSON_VALUE(json, '$.verb.id') IN (
            'https://w3id.org/xapi/video/verbs/played',
            'https://w3id.org/xapi/video/verbs/paused',
            'https://w3id.org/xapi/video/verbs/seeked',
            'https://w3id.org/xapi/video/verbs/completed',
            'http://adlnet.gov/expapi/verbs/experienced'
          ),
          JSON_VALUE(json, '$.object.id'),
          NULL
        ) AS video_url,
        toFloat64OrNull(JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/time"')) AS video_time,
        coalesce(
          toFloat64OrNull(JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/length"')),
          toFloat64OrNull(JSON_VALUE(json, '$.context.extensions."https://w3id.org/xapi/video/extensions/length"'))
        ) AS video_length,
        toFloat64OrNull(JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/progress"')) AS video_progress,
        JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/played-segments"') AS video_played_segments,
        toFloat64OrNull(JSON_VALUE(json, '$.result.extensions.video_play_time')) AS video_play_time,
        toFloat64OrNull(JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/time-from"')) AS video_seek_from,
        toFloat64OrNull(JSON_VALUE(json, '$.result.extensions."https://w3id.org/xapi/video/extensions/time-to"')) AS video_seek_to,

        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/activity_attempt_guid"') AS activity_attempt_guid,
        toUInt32OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/activity_attempt_number"')) AS activity_attempt_number,
        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/page_attempt_guid"') AS page_attempt_guid,
        toUInt32OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/page_attempt_number"')) AS page_attempt_number,
        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/part_attempt_guid"') AS part_attempt_guid,
        toUInt32OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/part_attempt_number"')) AS part_attempt_number,
        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/activity_id"')) AS activity_id,
        toUInt64OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/activity_revision_id"')) AS activity_revision_id,
        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/part_id"') AS part_id,

        JSON_VALUE(json, '$.object.definition.subType') AS page_sub_type,

        toFloat64OrNull(JSON_VALUE(json, '$.result.score.raw')) AS score,
        toFloat64OrNull(JSON_VALUE(json, '$.result.score.max')) AS out_of,
        toFloat64OrNull(JSON_VALUE(json, '$.result.score.scaled')) AS scaled_score,
        nullIf(JSON_VALUE(json, '$.result.success'), '') IN ('1', 'true', 'True') AS success,
        nullIf(JSON_VALUE(json, '$.result.completion'), '') IN ('1', 'true', 'True') AS completion,

        coalesce(
          JSON_VALUE(json, '$.result.response'),
          JSON_VALUE(json, '$.result.response.input'),
          JSON_QUERY(json, '$.result.response')
        ) AS response,

        JSON_VALUE(json, '$.result.extensions."http://oli.cmu.edu/extensions/feedback"') AS feedback,
        toUInt32OrNull(JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/hints_requested"')) AS hints_requested,
        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/attached_objectives"') AS attached_objectives,
        JSON_VALUE(json, '$.context.extensions."http://oli.cmu.edu/extensions/session_id"') AS session_id
    FROM #{s3_source}
    #{settings_clause}
    """
  end

  @doc """
  Construct a dry-run statement that inspects the S3 source without inserting
  any data.
  """
  @spec dry_run_sql(BackfillRun.t(), map()) :: String.t()
  def dry_run_sql(%BackfillRun{} = run, aws_creds) do
    s3_source = s3_source_clause(run, aws_creds)

    bytes_expression =
      case String.upcase(to_string(run.format || "")) do
        "JSONASSTRING" -> "sum(length(json)) AS total_bytes"
        _ -> "NULL AS total_bytes"
      end

    """
    SELECT
      count() AS total_rows,
      #{bytes_expression}
    FROM #{s3_source}
    """
  end

  defp s3_source_clause(%BackfillRun{format: format, s3_pattern: pattern}, %{} = creds) do
    key = Map.get(creds, :access_key_id) || Map.get(creds, "access_key_id")
    secret = Map.get(creds, :secret_access_key) || Map.get(creds, "secret_access_key")
    escaped_pattern = escape(pattern)
    escaped_key = escape(key)
    escaped_secret = escape(secret)

    case String.upcase(to_string(format || "")) do
      "JSONASSTRING" ->
        "s3('#{escaped_pattern}', '#{escaped_key}', '#{escaped_secret}', 'JSONAsString', 'json String')"

      other when other in ["JSONEACHROW", "JSONLINES"] ->
        "s3('#{escaped_pattern}', '#{escaped_key}', '#{escaped_secret}', '#{other}')"

      other ->
        "s3('#{escaped_pattern}', '#{escaped_key}', '#{escaped_secret}', '#{other}')"
    end
  end

  defp settings_clause(settings, aws_creds) do
    base_map =
      case settings do
        nil -> %{}
        %{} = map -> map
        _ -> %{}
      end

    settings_map =
      base_map
      |> Map.new()
      |> maybe_put_session_setting(aws_creds)

    if map_size(settings_map) == 0 do
      ""
    else
      formatted =
        settings_map
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.map(&format_setting/1)
        |> Enum.join(", ")

      case formatted do
        "" -> ""
        _ -> "SETTINGS " <> formatted
      end
    end
  end

  defp maybe_put_session_setting(settings, aws_creds) do
    raw_session =
      Map.get(aws_creds, :session_token) ||
        Map.get(aws_creds, "session_token")

    session = normalize_session_token(raw_session)

    case session do
      nil -> settings
      value -> Map.put(settings, :s3_session_token, value)
    end
  end

  defp normalize_session_token(nil), do: nil

  defp normalize_session_token(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        nil

      trimmed ->
        case String.downcase(trimmed) do
          "nil" -> nil
          "null" -> nil
          "none" -> nil
          _ -> trimmed
        end
    end
  end

  defp normalize_session_token(value) when is_atom(value),
    do: normalize_session_token(Atom.to_string(value))

  defp normalize_session_token(_), do: nil

  defp format_setting({key, value}) do
    formatted_key =
      key
      |> to_string()
      |> String.trim()

    formatted_value = format_setting_value(value)
    formatted_key <> " = " <> formatted_value
  end

  defp format_setting_value(value) when is_boolean(value), do: if(value, do: "1", else: "0")
  defp format_setting_value(value) when is_integer(value), do: Integer.to_string(value)

  defp format_setting_value(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact])

  defp format_setting_value(value) when is_binary(value) do
    "'" <> escape(value) <> "'"
  end

  defp format_setting_value(value), do: "'" <> escape(to_string(value)) <> "'"

  defp sanitize_target_table(table) when is_binary(table) do
    table
    |> String.trim()
    |> case do
      "" -> raise ArgumentError, "target_table must be provided"
      sanitized -> sanitized
    end
  end

  defp escape(nil), do: ""

  defp escape(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape(value), do: escape(to_string(value))
end

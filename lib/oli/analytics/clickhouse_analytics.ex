defmodule Oli.Analytics.ClickhouseAnalytics do
  @moduledoc """
  Provides advanced analytics capabilities for events stored in ClickHouse.

  This module includes health checks, queries, and utility functions
  for working with ClickHouse data.
  """
  alias Jason
  require Logger


  defp clickhouse_config do
    Application.get_env(:oli, :clickhouse, [])
    |> Enum.into(%{})
  end

  @doc """
  Checks if ClickHouse is available and responsive.
  """
  def health_check() do
    query = "SELECT 1"

    case execute_query(query, "health check") do
      {:ok, _} ->
        Logger.info("ClickHouse health check passed")
        {:ok, :healthy}

      {:error, reason} ->
        Logger.warning("ClickHouse health check failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Gets the fully qualified table name for the unified raw events table
  def raw_events_table() do
    config = clickhouse_config()
    "#{config.database}.raw_events"
  end

  @doc """
  Provides comprehensive analytics queries for all event types.
  Returns a map with query atoms as keys and maps containing description and query as values.
  """
  def sample_analytics_queries() do
    raw_events_table = raw_events_table()

    %{
      # Video Analytics
      video_engagement_by_section: %{
        description:
          "Analyzes video engagement metrics across different sections, including play/pause events, completion rates, and user participation.",
        query: """
          SELECT
            section_id,
            count(*) as total_events,
            countIf(video_time IS NOT NULL AND video_seek_from IS NULL) as play_pause_events,
            countIf(video_progress IS NOT NULL AND video_played_segments IS NOT NULL) as completion_events,
            countIf(video_seek_from IS NOT NULL AND video_seek_to IS NOT NULL) as seek_events,
            avg(video_progress) as avg_progress,
            uniq(user_id) as unique_users,
            uniq(content_element_id) as unique_videos
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'video'
          GROUP BY section_id
          ORDER BY total_events DESC
        """
      },
      video_completion_rates: %{
        description:
          "Shows completion rates for individual videos, highlighting which content is most engaging to learners.",
        query: """
          SELECT
            content_element_id,
            video_title,
            countIf(video_time IS NOT NULL) as plays,
            countIf(video_progress IS NOT NULL AND video_played_segments IS NOT NULL) as completions,
            if(plays > 0, completions / plays * 100, 0) as completion_rate_percent
          FROM #{raw_events_table}
          WHERE content_element_id IS NOT NULL AND event_type = 'video'
          GROUP BY content_element_id, video_title
          HAVING plays > 5
          ORDER BY completion_rate_percent DESC
        """
      },
      user_video_engagement: %{
        description:
          "Provides insights into individual user video watching patterns and engagement levels.",
        query: """
          SELECT
            user_id,
            count(*) as total_interactions,
            countIf(video_time IS NOT NULL) as videos_played,
            sum(video_play_time) as total_watch_time,
            avg(video_progress) as avg_completion_rate,
            max(timestamp) as last_interaction
          FROM #{raw_events_table}
          WHERE user_id IS NOT NULL AND event_type = 'video'
          GROUP BY user_id
          ORDER BY total_watch_time DESC
        """
      },

      # Activity Attempt Analytics
      activity_attempt_performance: %{
        description:
          "Analyzes performance metrics for activity attempts, showing success rates and average scores by section and activity.",
        query: """
          SELECT
            section_id,
            activity_id,
            count(*) as total_attempts,
            avg(score) as avg_score,
            avg(out_of) as avg_possible_score,
            avg(scaled_score) as avg_scaled_score,
            countIf(success = true) as successful_attempts,
            uniq(user_id) as unique_users
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'activity_attempt'
          GROUP BY section_id, activity_id
          ORDER BY avg_scaled_score DESC
        """
      },
      activity_attempt_trends: %{
        description:
          "Shows monthly trends in activity attempt performance and user engagement over time.",
        query: """
          SELECT
            toYYYYMM(timestamp) as month,
            section_id,
            count(*) as attempts,
            avg(scaled_score) as avg_performance,
            uniq(user_id) as active_users
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'activity_attempt'
          GROUP BY month, section_id
          ORDER BY month DESC, section_id
        """
      },

      # Page Attempt Analytics
      page_attempt_performance: %{
        description:
          "Evaluates page-level assessment performance, showing which pages students find most challenging.",
        query: """
          SELECT
            section_id,
            page_id,
            count(*) as total_attempts,
            avg(score) as avg_score,
            avg(out_of) as avg_possible_score,
            avg(scaled_score) as avg_scaled_score,
            countIf(success = true) as successful_attempts,
            uniq(user_id) as unique_users
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'page_attempt'
          GROUP BY section_id, page_id
          ORDER BY avg_scaled_score DESC
        """
      },

      # Page Viewed Analytics
      page_engagement: %{
        description:
          "Tracks page viewing patterns by time of day and completion rates to understand content engagement.",
        query: """
          SELECT
            section_id,
            page_id,
            page_sub_type,
            count(*) as total_views,
            uniq(user_id) as unique_viewers,
            countIf(completion = true) as completed_views,
            toHour(timestamp) as hour_of_day,
            count(*) as views_by_hour
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'page_viewed'
          GROUP BY section_id, page_id, page_sub_type, hour_of_day
          ORDER BY total_views DESC
        """
      },
      popular_pages: %{
        description:
          "Identifies the most popular pages based on view counts and completion rates across all sections.",
        query: """
          SELECT
            page_id,
            page_sub_type,
            count(*) as total_views,
            uniq(user_id) as unique_viewers,
            avg(if(completion = true, 1, 0)) as completion_rate
          FROM #{raw_events_table}
          WHERE page_id IS NOT NULL AND event_type = 'page_viewed'
          GROUP BY page_id, page_sub_type
          ORDER BY total_views DESC
        """
      },

      # Part Attempt Analytics
      part_attempt_analysis: %{
        description:
          "Provides detailed analysis of individual question parts within activities, including hint usage patterns.",
        query: """
          SELECT
            section_id,
            activity_id,
            part_id,
            count(*) as total_attempts,
            avg(score) as avg_score,
            avg(out_of) as avg_possible_score,
            avg(scaled_score) as avg_scaled_score,
            countIf(success = true) as successful_attempts,
            avg(hints_requested) as avg_hints_used,
            uniq(user_id) as unique_users
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL AND event_type = 'part_attempt'
          GROUP BY section_id, activity_id, part_id
          ORDER BY avg_scaled_score DESC
        """
      },

      # Cross-Event Analytics
      comprehensive_section_summary: %{
        description:
          "Provides a comprehensive overview of all event types by section, showing overall learning activity patterns.",
        query: """
          SELECT
            event_type,
            section_id,
            count(*) as total_events,
            uniq(user_id) as unique_users,
            min(timestamp) as earliest_event,
            max(timestamp) as latest_event
          FROM #{raw_events_table}
          WHERE section_id IS NOT NULL
          GROUP BY event_type, section_id
          ORDER BY section_id, event_type
        """
      },

      # Event Type Distribution
      event_type_distribution: %{
        description:
          "Shows the distribution of different event types across the entire platform to understand overall usage patterns.",
        query: """
          SELECT
            event_type,
            count(*) as total_events,
            uniq(user_id) as unique_users,
            min(timestamp) as earliest_event,
            max(timestamp) as latest_event
          FROM #{raw_events_table}
          GROUP BY event_type
          ORDER BY total_events DESC
        """
      }
    }
  end

  def humanize_query_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Get comprehensive analytics for a specific section across all event types.
  """
  def comprehensive_section_analytics(section_id) when is_integer(section_id) do
    raw_events_table = raw_events_table()

    """
    SELECT
      event_type,
      total_events,
      unique_users,
      earliest_event,
      latest_event,
      additional_info
    FROM (
      SELECT
        'video' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0, 'Watch time tracked', 'No video interactions') as additional_info
      FROM #{raw_events_table}
      WHERE section_id = #{section_id} AND event_type = 'video'

      UNION ALL

      SELECT
        'activity_attempt' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{raw_events_table}
      WHERE section_id = #{section_id} AND event_type = 'activity_attempt'

      UNION ALL

      SELECT
        'page_attempt' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{raw_events_table}
      WHERE section_id = #{section_id} AND event_type = 'page_attempt'

      UNION ALL

      SELECT
        'page_viewed' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Completed: ', toString(countIf(completion = true))),
           'No page views') as additional_info
      FROM #{raw_events_table}
      WHERE section_id = #{section_id} AND event_type = 'page_viewed'

      UNION ALL

      SELECT
        'part_attempt' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{raw_events_table}
      WHERE section_id = #{section_id} AND event_type = 'part_attempt'
    )
    ORDER BY
      CASE event_type
        WHEN 'video' THEN 1
        WHEN 'activity_attempt' THEN 2
        WHEN 'page_attempt' THEN 3
        WHEN 'page_viewed' THEN 4
        WHEN 'part_attempt' THEN 5
        ELSE 6
      END
    """
    |> execute_query("comprehensive section analytics for section #{section_id}")
  end

  @doc """
  Returns `{:ok, true}` when the ClickHouse raw events table already contains
  analytics data for the given section, and `{:ok, false}` when no records have
  been loaded yet. Any error returned from ClickHouse is propagated.
  """
  def section_analytics_loaded?(section_id) when is_integer(section_id) do
    raw_events_table = raw_events_table()

    """
    SELECT count() > 0 AS has_data
    FROM #{raw_events_table}
    WHERE section_id = #{section_id}
    """
    |> execute_query("section analytics load status for section #{section_id}")
    |> case do
      {:ok, %{parsed_body: %{"data" => data}} = result} when is_list(data) ->
        {:ok, parse_boolean_from_json(data) || parse_boolean_result(result.body)}

      {:ok, %{parsed_body: data} = result} when is_list(data) ->
        {:ok, parse_boolean_from_rows(data) || parse_boolean_result(result.body)}

      {:ok, %{body: body}} ->
        {:ok, parse_boolean_result(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def section_analytics_loaded?(_), do: {:error, :invalid_section_id}

  @doc """
  Retrieves the most recent ClickHouse query status for the provided `query_id`.
  """
  def query_status(query_id) when is_binary(query_id) and byte_size(query_id) > 0 do
    sanitized_id = escape_single_quotes(query_id)

    """
    SELECT
      query_id,
      type,
      exception,
      exception_code,
      read_rows AS rows_read,
      written_rows AS rows_written,
      read_bytes AS bytes_read,
      written_bytes AS bytes_written,
      memory_usage,
      query_duration_ms,
      event_time AS last_event_time
    FROM system.query_log
    WHERE query_id = '#{sanitized_id}'
      AND type IN ('QueryFinish', 'ExceptionBeforeStart', 'ExceptionWhileProcessing', 'QueryStart')
    ORDER BY event_time DESC
    LIMIT 1
    """
    |> execute_query("query status for #{query_id}")
    |> case do
      {:ok, response} -> parse_query_status(response)
      other -> other
    end
  end

  def query_status(_), do: {:error, :invalid_query_id}

  def execute_query(query, description, opts \\ [])
      when is_binary(query) and byte_size(query) > 0 do
    config = clickhouse_config()

    # Include database in the URL path for ClickHouse HTTP interface
    query_params = build_query_params(config, Keyword.get(opts, :query_params, %{}))
    url = build_clickhouse_url(config, query_params)

    extra_headers = Keyword.get(opts, :headers, [])

    headers =
      [
        {"Content-Type", "text/plain"},
        {"X-ClickHouse-User", config.user},
        {"X-ClickHouse-Key", config.password}
      ] ++ extra_headers

    # Add FORMAT clause to include headers in the output
    {formatted_query, response_format} = normalize_query_format(query)

    Logger.debug("Executing ClickHouse query for #{description}")

    http_options = build_http_options(config, opts)

    http_client =
      Oli.HTTP.http()
      |> ensure_http_client_module()

    # Time the query execution
    {execution_time_microseconds, result} =
      Oli.Timing.run(fn ->
        cond do
          function_exported?(http_client, :post, 4) ->
            apply(http_client, :post, [url, formatted_query, headers, http_options])

          function_exported?(http_client, :post, 3) ->
            Logger.debug(
              "HTTP client #{inspect(http_client)} only supports post/3; using default timeouts"
            )

            apply(http_client, :post, [url, formatted_query, headers])

          true ->
            raise ArgumentError,
                  "Configured HTTP client #{inspect(http_client)} does not define post/3 or post/4"
        end
      end)

    execution_time_ms = execution_time_microseconds / 1000

    case result do
      {:ok, %{status_code: 200} = response} ->
        Logger.debug("Successfully executed #{description} in #{execution_time_ms}ms")

        parsed_body = parse_query_body(response.body, response_format)

        formatted_response =
          response
          |> Map.put(:body, format_query_results(response.body, response_format))
          |> maybe_put_parsed_body(parsed_body)
          |> Map.put(:execution_time_ms, execution_time_ms)

        {:ok, formatted_response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Query \"#{description}\" failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request for query \"#{description}\" failed: #{inspect(reason)}"}
    end
  end

  def execute_query(_), do: {:error, "Empty query"}

  defp normalize_keyword_options(value) when is_list(value), do: value
  defp normalize_keyword_options(%{} = map), do: Enum.into(map, [])
  defp normalize_keyword_options(_), do: []


  defp build_http_options(config, opts) do
    provided =
      opts
      |> Keyword.get(:http_options, [])
      |> normalize_keyword_options()

    default_http_options(config)
    |> Keyword.merge(provided, fn _key, _default, override -> override end)
  end

  defp default_http_options(config) do
    base = [
      timeout: Map.get(config, :http_timeout_ms, 15_000),
      recv_timeout: Map.get(config, :http_recv_timeout_ms, 60_000)
    ]

    config
    |> Map.get(:http_options, [])
    |> normalize_keyword_options()
    |> Keyword.merge(base, fn _key, _base_value, config_value -> config_value end)
  end

  defp build_query_params(config, params) do
    params
    |> normalize_query_params()
    |> Map.put_new("database", config.database)
  end

  defp build_clickhouse_url(config, params) do
    query_string = URI.encode_query(params)
    "#{config.host}:#{config.http_port}/?#{query_string}"
  end

  defp normalize_query_params(params) when is_list(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_query_param_value(value))
    end)
  end

  defp normalize_query_params(%{} = params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_query_param_value(value))
    end)
  end

  defp normalize_query_params(_), do: %{}

  defp normalize_query_param_value(value) when is_binary(value), do: value

  defp normalize_query_param_value(value) when is_boolean(value),
    do: if(value, do: "1", else: "0")

  defp normalize_query_param_value(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_query_param_value(value) when is_float(value) do
    :erlang.float_to_binary(value, [:compact])
  end

  defp normalize_query_param_value(value), do: to_string(value)

  defp escape_single_quotes(nil), do: ""

  defp escape_single_quotes(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_single_quotes(value), do: escape_single_quotes(to_string(value))

  defp ensure_http_client_module({module, _default_opts}), do: ensure_http_client_module(module)

  defp ensure_http_client_module(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        module

      {:error, reason} ->
        raise ArgumentError,
              "Configured HTTP client #{inspect(module)} could not be loaded: #{inspect(reason)}"
    end
  end

  defp ensure_http_client_module(other) do
    raise ArgumentError, "Invalid HTTP client configuration: #{inspect(other)}"
  end

  defp format_query_results(body, format) when is_binary(body) do
    case {String.trim(body), format} do
      {"", _} ->
        ""

      {result, :json} ->
        format_json(result)

      {result, :jsoncompact} ->
        format_json(result)

      {result, :jsoncompacteachrow} ->
        format_json_each_row(result)

      {result, :jsonlines} ->
        format_json_each_row(result)

      {result, :tsvwithnames} ->
        result
        |> String.split("\n", trim: true)
        |> format_tsv_with_alignment()

      {result, _} ->
        result
    end
  end

  defp parse_query_body(body, format) when is_binary(body) do
    case format do
      format when format in [:json, :jsoncompact] ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          _ -> :error
        end

      format when format in [:jsoncompacteachrow, :jsonlines] ->
        body
        |> String.split("\n", trim: true)
        |> Enum.reduce_while([], fn line, acc ->
          case Jason.decode(line) do
            {:ok, decoded} -> {:cont, [decoded | acc]}
            _ -> {:halt, :error}
          end
        end)
        |> case do
          :error -> :error
          decoded_rows -> {:ok, Enum.reverse(decoded_rows)}
        end

      _ ->
        :error
    end
  end

  defp maybe_put_parsed_body(map, {:ok, parsed}), do: Map.put(map, :parsed_body, parsed)
  defp maybe_put_parsed_body(map, _), do: map

  defp parse_boolean_result(body) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [_header, value | _] -> parse_boolean_string(value)
      [value] -> parse_boolean_string(value)
      _ -> false
    end
  end

  defp parse_boolean_string(value) when is_binary(value) do
    case String.downcase(value) do
      "1" -> true
      "t" -> true
      "true" -> true
      "0" -> false
      "f" -> false
      "false" -> false
      _ -> false
    end
  end

  defp parse_boolean_from_json([]), do: nil

  defp parse_boolean_from_json([row | _]) when is_map(row) do
    row
    |> fetch_has_data_field()
    |> case do
      nil -> nil
      value when is_boolean(value) -> value
      value when is_integer(value) -> value != 0
      value when is_binary(value) -> parse_boolean_string(value)
      _ -> nil
    end
  end

  defp parse_boolean_from_json(_), do: nil

  defp parse_boolean_from_rows([]), do: nil

  defp parse_boolean_from_rows([row | _]) when is_map(row) do
    row
    |> fetch_has_data_field()
    |> case do
      nil -> nil
      value when is_boolean(value) -> value
      value when is_integer(value) -> value != 0
      value when is_binary(value) -> parse_boolean_string(value)
      _ -> nil
    end
  end

  defp parse_boolean_from_rows(_), do: nil

  defp fetch_has_data_field(row) do
    cond do
      Map.has_key?(row, "has_data") -> Map.get(row, "has_data")
      Map.has_key?(row, :has_data) -> Map.get(row, :has_data)
      true -> nil
    end
  end

  defp parse_query_status(%{parsed_body: parsed}) when is_map(parsed) do
    parsed
    |> Map.get("data")
    |> case do
      nil -> {:ok, %{status: :running}}
      data -> parse_query_status_from_data(data)
    end
  end

  defp parse_query_status(%{parsed_body: parsed}) when is_list(parsed) do
    parse_query_status_from_data(parsed)
  end

  defp parse_query_status(_), do: {:ok, %{status: :running}}

  defp parse_query_status_from_data([]), do: {:ok, %{status: :running}}

  defp parse_query_status_from_data([row | _]) when is_map(row) do
    status =
      row
      |> fetch_row_value("type")
      |> case do
        "QueryFinish" -> :completed
        "ExceptionBeforeStart" -> :failed
        "ExceptionWhileProcessing" -> :failed
        _ -> :running
      end

    info =
      %{
        query_id: fetch_row_value(row, "query_id"),
        status: status,
        rows_read: parse_integer_field(row, "rows_read"),
        rows_written: parse_integer_field(row, "rows_written"),
        bytes_read: parse_integer_field(row, "bytes_read"),
        bytes_written: parse_integer_field(row, "bytes_written"),
        memory_usage: parse_integer_field(row, "memory_usage"),
        query_duration_ms: parse_integer_field(row, "query_duration_ms"),
        exception_code: parse_integer_field(row, "exception_code"),
        error: parse_error_message(row),
        last_event_time: parse_event_time_field(row, "last_event_time")
      }
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        cond do
          key == :status -> Map.put(acc, key, value)
          is_nil(value) -> acc
          true -> Map.put(acc, key, value)
        end
      end)

    {:ok, info}
  end

  defp parse_query_status_from_data(_), do: {:ok, %{status: :running}}

  defp fetch_row_value(row, key) do
    string_key = if is_atom(key), do: Atom.to_string(key), else: to_string(key)
    Map.get(row, string_key) || Map.get(row, key)
  end

  defp parse_integer_field(row, key) do
    row
    |> fetch_row_value(key)
    |> normalize_integer_value()
  end

  defp normalize_integer_value(nil), do: nil
  defp normalize_integer_value(value) when is_integer(value), do: value
  defp normalize_integer_value(value) when is_float(value), do: trunc(value)

  defp normalize_integer_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        nil

      true ->
        case Integer.parse(trimmed) do
          {int, _} ->
            int

          :error ->
            case Float.parse(trimmed) do
              {float, _} -> trunc(float)
              :error -> nil
            end
        end
    end
  end

  defp normalize_integer_value(_), do: nil

  defp parse_error_message(row) do
    row
    |> fetch_row_value("exception")
    |> case do
      nil -> nil
      "" -> nil
      message -> message
    end
  end

  defp parse_event_time_field(row, key) do
    row
    |> fetch_row_value(key)
    |> case do
      nil -> nil
      %DateTime{} = dt -> dt
      %NaiveDateTime{} = dt -> dt
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end

  defp format_tsv_with_alignment([]), do: ""
  defp format_tsv_with_alignment([single_line]), do: single_line

  defp format_tsv_with_alignment([header | data_lines]) do
    # Parse all lines into columns
    all_rows = [header | data_lines] |> Enum.map(&String.split(&1, "\t"))

    # Calculate max width for each column
    column_widths = calculate_column_widths(all_rows)

    # Format header
    formatted_header = format_row(String.split(header, "\t"), column_widths)

    # Create separator line
    separator = create_separator_line(column_widths)

    # Format data rows
    formatted_data =
      data_lines
      |> Enum.map(&String.split(&1, "\t"))
      |> Enum.map(&format_row(&1, column_widths))

    # Combine all parts
    [formatted_header, separator | formatted_data]
    |> Enum.join("\n")
  end

  defp normalize_query_format(query) do
    case extract_explicit_format(query) do
      {:ok, format} ->
        {query, format}

      :none ->
        if select_query?(query) do
          {query <> " FORMAT JSON", :json}
        else
          {query, :unknown}
        end
    end
  end

  defp select_query?(query) when is_binary(query) do
    query
    |> String.trim_leading()
    |> String.downcase()
    |> String.starts_with?("select")
  end

  defp extract_explicit_format(query) do
    case Regex.run(~r/FORMAT\s+([A-Za-z_]+)/i, query, capture: :all_but_first) do
      [format] ->
        {:ok, format_atom(format)}

      _ ->
        :none
    end
  end

  defp format_atom(format) do
    format
    |> String.trim()
    |> String.downcase()
    |> case do
      "json" -> :json
      "jsoncompact" -> :jsoncompact
      "jsoncompacteachrow" -> :jsoncompacteachrow
      "jsoneachrow" -> :jsonlines
      "jsonlines" -> :jsonlines
      "tsvwithnames" -> :tsvwithnames
      value -> String.to_atom(value)
    end
  end

  defp format_json(result) do
    case Jason.decode(result) do
      {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
      _ -> result
    end
  end

  defp format_json_each_row(result) do
    result
    |> String.split("\n", trim: true)
    |> Enum.map(fn row ->
      case Jason.decode(row) do
        {:ok, decoded} -> Jason.encode!(decoded)
        _ -> row
      end
    end)
    |> Enum.join("\n")
  end

  defp calculate_column_widths(rows) do
    rows
    |> Enum.reduce([], fn row, acc ->
      row
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {cell, index}, widths ->
        cell_length = String.length(to_string(cell))
        current_width = Enum.at(widths, index, 0)

        List.replace_at(
          widths ++ List.duplicate(0, max(0, index + 1 - length(widths))),
          index,
          max(current_width, cell_length)
        )
      end)
    end)
  end

  defp format_row(columns, widths) do
    columns
    |> Enum.with_index()
    |> Enum.map(fn {cell, index} ->
      width = Enum.at(widths, index, 0)
      String.pad_trailing(to_string(cell), width)
    end)
    |> Enum.join(" | ")
  end

  defp create_separator_line(widths) do
    widths
    |> Enum.map(&String.duplicate("-", &1))
    |> Enum.join("-|-")
  end
end

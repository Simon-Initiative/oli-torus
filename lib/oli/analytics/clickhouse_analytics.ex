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

  defp fetch_health_metadata(database) do
    query = """
    SELECT
      version() AS version,
      uptime() AS uptime_seconds,
      timezone() AS timezone,
      hostName() AS hostname,
      now() AS server_time,
      currentDatabase() AS current_database,
      '#{escape_single_quotes(database)}' AS configured_database
    """

    query
    |> execute_query("clickhouse health metadata")
    |> extract_single_row()
  end

  defp fetch_table_metrics(database, table) do
    query = """
    SELECT
      name,
      engine,
      total_rows,
      total_bytes,
      metadata_modification_time
    FROM system.tables
    WHERE database = '#{escape_single_quotes(database)}'
      AND name = '#{escape_single_quotes(table)}'
    """

    query
    |> execute_query("clickhouse table metrics")
    |> case do
      {:ok, %{parsed_body: %{"data" => []}}} -> {:ok, %{"name" => table}}
      other -> extract_single_row(other)
    end
    |> ensure_table_metrics_defaults(table)
  end

  defp fetch_table_parts_metrics(database, table) do
    query = """
    SELECT
      countIf(active = 1) AS active_parts,
      max(modification_time) AS last_part_modification,
      sum(bytes_on_disk) AS bytes_on_disk,
      sum(rows) AS rows_on_disk
    FROM system.parts
    WHERE database = '#{escape_single_quotes(database)}'
      AND table = '#{escape_single_quotes(table)}'
    """

    query
    |> execute_query("clickhouse parts metrics")
    |> case do
      {:ok, %{parsed_body: %{"data" => []}}} -> {:ok, %{}}
      other -> extract_single_row(other)
    end
    |> ensure_parts_metrics_defaults()
  end

  defp extract_single_row({:ok, %{parsed_body: %{"data" => [row | _]}}}) when is_map(row),
    do: {:ok, row}

  defp extract_single_row({:ok, %{parsed_body: rows}}) when is_list(rows) and rows != [] do
    case List.first(rows) do
      row when is_map(row) -> {:ok, row}
      _ -> {:error, "Unexpected query response shape"}
    end
  end

  defp extract_single_row({:ok, _}),
    do: {:error, "ClickHouse returned no data for health query"}

  defp extract_single_row({:error, reason}), do: {:error, reason}

  defp ensure_table_metrics_defaults({:ok, row}, table) do
    {:ok,
     row
     |> Map.put_new("name", table)
     |> Map.put_new("engine", nil)
     |> Map.put_new("total_rows", nil)
     |> Map.put_new("total_bytes", nil)
     |> Map.put_new("metadata_modification_time", nil)}
  end

  defp ensure_table_metrics_defaults({:error, reason}, _table), do: {:error, reason}

  defp ensure_parts_metrics_defaults({:ok, row}) do
    {:ok,
     row
     |> Map.put_new("active_parts", 0)
     |> Map.put_new("last_part_modification", nil)
     |> Map.put_new("bytes_on_disk", 0)
     |> Map.put_new("rows_on_disk", 0)}
  end

  defp ensure_parts_metrics_defaults({:error, reason}), do: {:error, reason}

  @doc """
  Collects ClickHouse health metadata and table-level metrics for observability.
  """
  def health_summary do
    database = clickhouse_config().database

    with {:ok, base} <- fetch_health_metadata(database),
         {:ok, table} <- fetch_table_metrics(database, "raw_events"),
         {:ok, parts} <- fetch_table_parts_metrics(database, "raw_events") do
      {:ok,
       base
       |> Map.put(:raw_events, table)
       |> Map.put(:raw_events_parts, parts)}
    end
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

  @doc """
  Fetches the current progress for a running ClickHouse query by inspecting
  `system.processes`. Returns `{:ok, %{status: :running, ...}}` when the query is
  active, `{:ok, :none}` when no matching process exists, or `{:error, reason}`
  if the lookup fails.
  """
  def query_progress(query_id) when is_binary(query_id) and byte_size(query_id) > 0 do
    sanitized_id = escape_single_quotes(query_id)

    """
    SELECT
      read_rows,
      read_bytes,
      written_rows,
      written_bytes,
      memory_usage,
      elapsed,
      total_rows_approx
    FROM system.processes
    WHERE query_id = '#{sanitized_id}'
    LIMIT 1
    """
    |> execute_query("query progress for #{query_id}")
    |> case do
      {:ok, response} -> parse_query_progress(response)
      other -> other
    end
  end

  def query_progress(_), do: {:error, :invalid_query_id}

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

  defp parse_query_progress(%{parsed_body: %{"data" => [row | _]}}) when is_map(row) do
    elapsed_seconds = parse_float_field(row, "elapsed")
    elapsed_ms = if is_number(elapsed_seconds), do: elapsed_seconds * 1_000.0, else: nil

    {:ok,
     %{
       status: :running,
       read_rows: parse_integer_field(row, "read_rows"),
       read_bytes: parse_integer_field(row, "read_bytes"),
       written_rows: parse_integer_field(row, "written_rows"),
       written_bytes: parse_integer_field(row, "written_bytes"),
       memory_usage: parse_integer_field(row, "memory_usage"),
       elapsed_ms: elapsed_ms,
       total_rows: parse_integer_field(row, "total_rows"),
       total_rows_approx: parse_integer_field(row, "total_rows_approx"),
       total_bytes: parse_integer_field(row, "total_bytes"),
       total_bytes_approx: parse_integer_field(row, "total_bytes_approx")
     }}
  end

  defp parse_query_progress(%{parsed_body: %{"data" => []}}), do: {:ok, :none}
  defp parse_query_progress(%{parsed_body: []}), do: {:ok, :none}

  defp parse_query_progress(%{parsed_body: parsed}) when is_map(parsed) do
    parsed
    |> Map.get("data", [])
    |> case do
      [] -> {:ok, :none}
      list when is_list(list) -> parse_query_progress(%{parsed_body: %{"data" => list}})
    end
  end

  defp parse_query_progress(_), do: {:ok, :none}

  defp fetch_row_value(row, key) do
    string_key = if is_atom(key), do: Atom.to_string(key), else: to_string(key)
    Map.get(row, string_key) || Map.get(row, key)
  end

  defp parse_integer_field(row, key) do
    row
    |> fetch_row_value(key)
    |> normalize_integer_value()
  end

  defp parse_float_field(row, key) do
    row
    |> fetch_row_value(key)
    |> normalize_float_value()
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

  defp normalize_float_value(nil), do: nil
  defp normalize_float_value(value) when is_float(value), do: value
  defp normalize_float_value(value) when is_integer(value), do: value * 1.0

  defp normalize_float_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        nil

      true ->
        case Float.parse(trimmed) do
          {float, _} -> float
          :error -> nil
        end
    end
  end

  defp normalize_float_value(_value), do: nil

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

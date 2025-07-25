defmodule Oli.Analytics.AdvancedAnalytics do
  @moduledoc """
  Provides advanced analytics capabilities for events stored in ClickHouse.

  This module includes health checks, queries, and utility functions
  for working with ClickHouse data.
  """
  require Logger

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

  @doc """
  Provides useful analytics queries for video events.
  """
  def sample_video_analytics_queries() do
    %{
      video_engagement_by_section: """
        SELECT
          section_id,
          count(*) as total_events,
          countIf(verb LIKE '%played%') as play_events,
          countIf(verb LIKE '%paused%') as pause_events,
          countIf(verb LIKE '%completed%') as completion_events,
          avg(video_progress) as avg_progress,
          uniq(user_id) as unique_users,
          uniq(content_element_id) as unique_videos
        FROM video_events
        WHERE section_id IS NOT NULL
        GROUP BY section_id
        ORDER BY total_events DESC
      """,
      video_completion_rates: """
        SELECT
          content_element_id,
          video_title,
          countIf(verb LIKE '%played%') as plays,
          countIf(verb LIKE '%completed%') as completions,
          if(plays > 0, completions / plays * 100, 0) as completion_rate_percent
        FROM video_events
        WHERE content_element_id IS NOT NULL
        GROUP BY content_element_id, video_title
        HAVING plays > 5
        ORDER BY completion_rate_percent DESC
      """,
      user_video_engagement: """
        SELECT
          user_id,
          count(*) as total_interactions,
          countIf(verb LIKE '%played%') as videos_played,
          sum(video_play_time) as total_watch_time,
          avg(video_progress) as avg_completion_rate,
          max(timestamp) as last_interaction
        FROM video_events
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        ORDER BY total_watch_time DESC
      """
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
  Provides useful analytics queries for video events.
  """
  def video_engagement_by_section(section_id) when is_integer(section_id) do
    """
      SELECT
        section_id,
        count(*) as total_events,
        countIf(verb LIKE '%played%') as play_events,
        countIf(verb LIKE '%paused%') as pause_events,
        countIf(verb LIKE '%completed%') as completion_events,
        avg(video_progress) as avg_progress,
        uniq(user_id) as unique_users,
        uniq(content_element_id) as unique_videos
      FROM video_events
      WHERE section_id = '#{section_id}'
        AND section_id IS NOT NULL
      GROUP BY section_id
      ORDER BY total_events DESC
    """
    |> execute_query("video engagement by section")
  end

  def execute_query(query, description) when is_binary(query) and byte_size(query) > 0 do
    config = get_clickhouse_config()
    url = "#{config.host}:#{config.port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    # Add FORMAT clause to include headers in the output
    formatted_query =
      if String.contains?(String.downcase(query), "format") do
        query
      else
        query <> " FORMAT TSVWithNames"
      end

    Logger.debug("Executing ClickHouse query for #{description}")

    case Oli.HTTP.http().post(url, formatted_query, headers) do
      {:ok, %{status_code: 200} = response} ->
        Logger.debug("Successfully executed #{description}")

        formatted_response = %{response | body: format_query_results(response.body)}
        {:ok, formatted_response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Query \"#{description}\" failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request for query \"#{description}\" failed: #{inspect(reason)}"}
    end
  end

  def execute_query(_), do: {:error, "Empty query"}

  defp format_query_results(body) when is_binary(body) do
    case String.trim(body) do
      "" ->
        ""

      result ->
        lines = String.split(result, "\n", trim: true)
        format_tsv_with_alignment(lines)
    end
  end

  defp get_clickhouse_config() do
    %{
      host: Application.get_env(:oli, :clickhouse_host, "http://localhost"),
      port: Application.get_env(:oli, :clickhouse_port, 8123),
      user: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, "")
    }
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

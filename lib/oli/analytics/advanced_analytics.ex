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

  # Gets the fully qualified table names for all event types
  def video_events_table() do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})
    "#{config.database}.video_events"
  end

  def activity_attempt_events_table() do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})
    "#{config.database}.activity_attempt_events"
  end

  def page_attempt_events_table() do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})
    "#{config.database}.page_attempt_events"
  end

  def page_viewed_events_table() do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})
    "#{config.database}.page_viewed_events"
  end

  def part_attempt_events_table() do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})
    "#{config.database}.part_attempt_events"
  end

  @doc """
  Provides comprehensive analytics queries for all event types.
  """
  def sample_analytics_queries() do
    video_events_table = video_events_table()
    activity_attempt_events_table = activity_attempt_events_table()
    page_attempt_events_table = page_attempt_events_table()
    page_viewed_events_table = page_viewed_events_table()
    part_attempt_events_table = part_attempt_events_table()

    %{
      # Video Analytics
      video_engagement_by_section: """
        SELECT
          section_id,
          count(*) as total_events,
          countIf(video_time IS NOT NULL AND video_seek_from IS NULL) as play_pause_events,
          countIf(video_progress IS NOT NULL AND video_played_segments IS NOT NULL) as completion_events,
          countIf(video_seek_from IS NOT NULL AND video_seek_to IS NOT NULL) as seek_events,
          avg(video_progress) as avg_progress,
          uniq(user_id) as unique_users,
          uniq(content_element_id) as unique_videos
        FROM #{video_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id
        ORDER BY total_events DESC
      """,
      video_completion_rates: """
        SELECT
          content_element_id,
          video_title,
          countIf(video_time IS NOT NULL) as plays,
          countIf(video_progress IS NOT NULL AND video_played_segments IS NOT NULL) as completions,
          if(plays > 0, completions / plays * 100, 0) as completion_rate_percent
        FROM #{video_events_table}
        WHERE content_element_id IS NOT NULL
        GROUP BY content_element_id, video_title
        HAVING plays > 5
        ORDER BY completion_rate_percent DESC
      """,
      user_video_engagement: """
        SELECT
          user_id,
          count(*) as total_interactions,
          countIf(video_time IS NOT NULL) as videos_played,
          sum(video_play_time) as total_watch_time,
          avg(video_progress) as avg_completion_rate,
          max(timestamp) as last_interaction
        FROM #{video_events_table}
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        ORDER BY total_watch_time DESC
      """,

      # Activity Attempt Analytics
      activity_attempt_performance: """
        SELECT
          section_id,
          activity_id,
          count(*) as total_attempts,
          avg(score) as avg_score,
          avg(out_of) as avg_possible_score,
          avg(scaled_score) as avg_scaled_score,
          countIf(success = true) as successful_attempts,
          uniq(user_id) as unique_users
        FROM #{activity_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id, activity_id
        ORDER BY avg_scaled_score DESC
      """,
      activity_attempt_trends: """
        SELECT
          toYYYYMM(timestamp) as month,
          section_id,
          count(*) as attempts,
          avg(scaled_score) as avg_performance,
          uniq(user_id) as active_users
        FROM #{activity_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY month, section_id
        ORDER BY month DESC, section_id
      """,

      # Page Attempt Analytics
      page_attempt_performance: """
        SELECT
          section_id,
          page_id,
          count(*) as total_attempts,
          avg(score) as avg_score,
          avg(out_of) as avg_possible_score,
          avg(scaled_score) as avg_scaled_score,
          countIf(success = true) as successful_attempts,
          uniq(user_id) as unique_users
        FROM #{page_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id, page_id
        ORDER BY avg_scaled_score DESC
      """,

      # Page Viewed Analytics
      page_engagement: """
        SELECT
          section_id,
          page_id,
          page_sub_type,
          count(*) as total_views,
          uniq(user_id) as unique_viewers,
          countIf(completion = true) as completed_views,
          toHour(timestamp) as hour_of_day,
          count(*) as views_by_hour
        FROM #{page_viewed_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id, page_id, page_sub_type, hour_of_day
        ORDER BY total_views DESC
      """,
      popular_pages: """
        SELECT
          page_id,
          page_sub_type,
          count(*) as total_views,
          uniq(user_id) as unique_viewers,
          avg(if(completion = true, 1, 0)) as completion_rate
        FROM #{page_viewed_events_table}
        WHERE page_id IS NOT NULL
        GROUP BY page_id, page_sub_type
        ORDER BY total_views DESC
      """,

      # Part Attempt Analytics
      part_attempt_analysis: """
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
        FROM #{part_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id, activity_id, part_id
        ORDER BY avg_scaled_score DESC
      """,

      # Cross-Event Analytics
      comprehensive_section_summary: """
        SELECT
          'video_events' as event_type,
          section_id,
          count(*) as total_events,
          uniq(user_id) as unique_users,
          min(timestamp) as earliest_event,
          max(timestamp) as latest_event
        FROM #{video_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id

        UNION ALL

        SELECT
          'activity_attempts' as event_type,
          section_id,
          count(*) as total_events,
          uniq(user_id) as unique_users,
          min(timestamp) as earliest_event,
          max(timestamp) as latest_event
        FROM #{activity_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id

        UNION ALL

        SELECT
          'page_attempts' as event_type,
          section_id,
          count(*) as total_events,
          uniq(user_id) as unique_users,
          min(timestamp) as earliest_event,
          max(timestamp) as latest_event
        FROM #{page_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id

        UNION ALL

        SELECT
          'page_views' as event_type,
          section_id,
          count(*) as total_events,
          uniq(user_id) as unique_users,
          min(timestamp) as earliest_event,
          max(timestamp) as latest_event
        FROM #{page_viewed_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id

        UNION ALL

        SELECT
          'part_attempts' as event_type,
          section_id,
          count(*) as total_events,
          uniq(user_id) as unique_users,
          min(timestamp) as earliest_event,
          max(timestamp) as latest_event
        FROM #{part_attempt_events_table}
        WHERE section_id IS NOT NULL
        GROUP BY section_id

        ORDER BY section_id, event_type
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
  Get comprehensive analytics for a specific section across all event types.
  """
  def comprehensive_section_analytics(section_id) when is_integer(section_id) do
    video_events_table = video_events_table()
    activity_attempt_events_table = activity_attempt_events_table()
    page_attempt_events_table = page_attempt_events_table()
    page_viewed_events_table = page_viewed_events_table()
    part_attempt_events_table = part_attempt_events_table()

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
        'video_events' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0, 'Watch time tracked', 'No video interactions') as additional_info
      FROM #{video_events_table}
      WHERE section_id = #{section_id}

      UNION ALL

      SELECT
        'activity_attempts' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{activity_attempt_events_table}
      WHERE section_id = #{section_id}

      UNION ALL

      SELECT
        'page_attempts' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{page_attempt_events_table}
      WHERE section_id = #{section_id}

      UNION ALL

      SELECT
        'page_views' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Completed: ', toString(countIf(completion = true))),
           'No page views') as additional_info
      FROM #{page_viewed_events_table}
      WHERE section_id = #{section_id}

      UNION ALL

      SELECT
        'part_attempts' as event_type,
        count(*) as total_events,
        uniq(user_id) as unique_users,
        min(timestamp) as earliest_event,
        max(timestamp) as latest_event,
        if(count(*) > 0,
           concat('Avg score: ', toString(round(avg(scaled_score), 3))),
           'No attempts recorded') as additional_info
      FROM #{part_attempt_events_table}
      WHERE section_id = #{section_id}
    )
    ORDER BY
      CASE event_type
        WHEN 'video_events' THEN 1
        WHEN 'activity_attempts' THEN 2
        WHEN 'page_attempts' THEN 3
        WHEN 'page_views' THEN 4
        WHEN 'part_attempts' THEN 5
        ELSE 6
      END
    """
    |> execute_query("comprehensive section analytics for section #{section_id}")
  end

  def execute_query(query, description) when is_binary(query) and byte_size(query) > 0 do
    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})

    # Include database in the URL path for ClickHouse HTTP interface
    url = "#{config.host}:#{config.port}/?database=#{config.database}"

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

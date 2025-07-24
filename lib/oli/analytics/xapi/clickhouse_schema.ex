defmodule Oli.Analytics.XAPI.ClickHouseSchema do
  @moduledoc """
  Manages ClickHouse table schemas for xAPI analytics.
  Provides functions to create and migrate OLAP tables.
  """

  alias Oli.HTTP
  require Logger

  @doc """
  Creates the video_events table in ClickHouse if it doesn't exist.
  """
  def create_video_events_table() do
    query = """
    CREATE TABLE IF NOT EXISTS video_events (
      event_id String,
      timestamp DateTime64(3),
      user_id String DEFAULT '',
      session_id Nullable(String),
      section_id UInt64 DEFAULT 0,
      page_id Nullable(UInt64),
      content_element_id Nullable(String),
      video_url Nullable(String),
      video_title Nullable(String),
      verb Nullable(String),
      video_time Nullable(Float64),
      video_length Nullable(Float64),
      video_progress Nullable(Float64),
      video_played_segments Nullable(String),
      video_play_time Nullable(Float64),
      video_seek_from Nullable(Float64),
      video_seek_to Nullable(Float64),
      inserted_at DateTime DEFAULT now()
    ) ENGINE = MergeTree()
    ORDER BY (timestamp, section_id, user_id)
    PARTITION BY toYYYYMM(timestamp)
    """

    execute_query(query, "video_events table")
  end

  @doc """
  Creates all necessary analytics tables.
  """
  def create_all_tables() do
    results = [
      create_video_events_table()
    ]

    case Enum.all?(results, &match?({:ok, _}, &1)) do
      true ->
        Logger.info("All ClickHouse analytics tables created successfully")
        {:ok, :all_tables_created}

      false ->
        failed = Enum.filter(results, &match?({:error, _}, &1))
        Logger.error("Failed to create some ClickHouse tables: #{inspect(failed)}")
        {:error, :table_creation_failed}
    end
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

  defp execute_query(query, description) do
    config = get_clickhouse_config()
    url = "#{config.host}:#{config.port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    Logger.debug("Executing ClickHouse query for #{description}")

    case HTTP.http().post(url, query, headers) do
      {:ok, %{status_code: 200} = response} ->
        Logger.debug("Successfully executed #{description}")
        {:ok, response}

      {:ok, %{status_code: status_code, body: body}} ->
        error = "ClickHouse #{description} failed with status #{status_code}: #{body}"
        Logger.error(error)
        {:error, error}

      {:error, reason} ->
        error = "HTTP request for #{description} failed: #{inspect(reason)}"
        Logger.error(error)
        {:error, error}
    end
  end

  defp get_clickhouse_config() do
    %{
      host: Application.get_env(:oli, :clickhouse_host, "http://localhost"),
      port: Application.get_env(:oli, :clickhouse_port, 8123),
      user: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, ""),
      database: Application.get_env(:oli, :clickhouse_database, "default")
    }
  end
end

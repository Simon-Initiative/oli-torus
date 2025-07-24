defmodule Mix.Tasks.Oli.Clickhouse.Setup do
  @moduledoc """
  Sets up ClickHouse tables and schema for xAPI analytics.

  ## Examples

      # Set up all tables
      mix oli.clickhouse.setup

      # Check ClickHouse health
      mix oli.clickhouse.setup --health-check

      # Create only video events table
      mix oli.clickhouse.setup --video-only
  """

  use Mix.Task
  alias Oli.Analytics.XAPI.ClickHouseSchema
  require Logger

  @shortdoc "Set up ClickHouse for xAPI analytics"

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["--health-check"] ->
        health_check()

      ["--video-only"] ->
        video_events_only()

      _ ->
        full_setup()
    end
  end

  defp full_setup() do
    Logger.info("🚀 Setting up ClickHouse for xAPI analytics...")

    case ClickHouseSchema.health_check() do
      {:ok, :healthy} ->
        Logger.info("✅ ClickHouse is healthy and reachable")

        case ClickHouseSchema.create_all_tables() do
          {:ok, :all_tables_created} ->
            Logger.info("✅ All ClickHouse analytics tables created successfully")
            Logger.info("🎯 Setup complete! You can now collect xAPI analytics in development")
            show_sample_queries()

          {:error, reason} ->
            Logger.error("❌ Failed to create tables: #{inspect(reason)}")
            Mix.shell().error("Setup failed. Please check ClickHouse configuration.")
        end

      {:error, reason} ->
        Logger.error("❌ ClickHouse health check failed: #{inspect(reason)}")
        Logger.error("💡 Make sure ClickHouse is running: docker-compose up clickhouse")
        Mix.shell().error("ClickHouse is not available. Please start it first.")
    end
  end

  defp health_check() do
    Logger.info("🔍 Checking ClickHouse health...")

    case ClickHouseSchema.health_check() do
      {:ok, :healthy} ->
        Logger.info("✅ ClickHouse is healthy and reachable")

      {:error, reason} ->
        Logger.error("❌ ClickHouse health check failed: #{inspect(reason)}")
        Logger.error("💡 Make sure ClickHouse is running: docker-compose up clickhouse")
    end
  end

  defp video_events_only() do
    Logger.info("🎬 Setting up video events table in ClickHouse...")

    case ClickHouseSchema.health_check() do
      {:ok, :healthy} ->
        case ClickHouseSchema.create_video_events_table() do
          {:ok, _} ->
            Logger.info("✅ Video events table created successfully")

          {:error, reason} ->
            Logger.error("❌ Failed to create video events table: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.error("❌ ClickHouse not available: #{inspect(reason)}")
    end
  end

  defp show_sample_queries() do
    Logger.info("\n📊 Sample analytics queries you can run:")

    queries = ClickHouseSchema.sample_video_analytics_queries()

    Enum.each(queries, fn {name, query} ->
      Logger.info("\n🔍 #{name}:")
      Logger.info(String.trim(query))
    end)

    Logger.info("\n💡 Run these queries in ClickHouse client or through HTTP interface")

    Logger.info(
      "   Example: curl -X POST 'http://localhost:8123' -d 'SELECT count() FROM video_events'"
    )
  end
end

defmodule Mix.Tasks.Clickhouse.Migrate do
  @moduledoc """
  Manage ClickHouse migrations using goose.

  Available commands:
    mix clickhouse.migrate status  # Show migration status
    mix clickhouse.migrate up      # Run pending migrations
    mix clickhouse.migrate down    # Rollback one migration
    mix clickhouse.migrate create <name>  # Create new migration
    mix clickhouse.migrate setup   # Create database and run all migrations
    mix clickhouse.migrate reset   # Drop and recreate database from scratch
    mix clickhouse.migrate drop    # Drop the database
  """

  use Mix.Task

  @shortdoc "Manage ClickHouse migrations using goose"

  @doc false
  def run(args) do
    Mix.Task.run("app.start")

    command =
      case args do
        [] -> "up"
        [cmd] -> cmd
        [cmd | _] -> cmd
      end

    config = Application.get_env(:oli, :clickhouse) |> Enum.into(%{})

    case command do
      "up" ->
        IO.puts("Running ClickHouse migrations...")
        run_migrate_command("up", config)

      "down" ->
        IO.puts("Rolling back ClickHouse migration...")
        run_migrate_command("down", config)

      "status" ->
        IO.puts("Checking ClickHouse migration status...")
        run_migrate_command("status", config)

      "create" ->
        IO.puts("Creating new ClickHouse migration...")
        create_migration(args)

      "setup" ->
        IO.puts("Setting up ClickHouse database...")
        setup_database(config)

      "reset" ->
        IO.puts("Resetting ClickHouse database...")
        reset_database(config)

      "drop" ->
        IO.puts("Dropping ClickHouse database...")
        drop_database_command(config)

      _ ->
        Mix.raise(
          "Unknown command: #{command}. Available commands: up, down, status, create, setup, reset, drop"
        )
    end
  end

  defp run_migrate_command(command, config) do
    case System.find_executable("goose") do
      nil ->
        error_message = """
        ❌ goose executable not found in PATH

        Please install goose:
          macOS: brew install goose
          Linux: go install github.com/pressly/goose/v3/cmd/goose@latest
          Or visit: https://github.com/pressly/goose
        """

        Mix.raise(error_message)

      goose_path ->
        database_url = build_database_url(config)
        migrations_dir = Path.join([File.cwd!(), "priv", "clickhouse", "migrations"])

        IO.puts("Migrations directory: #{migrations_dir}")

        # Test ClickHouse connection first
        with :ok <- test_clickhouse_connection(config) do
          goose_args = [
            "-dir",
            migrations_dir,
            "clickhouse",
            database_url,
            command
          ]

          case System.cmd(goose_path, goose_args, stderr_to_stdout: true) do
            {output, 0} ->
              IO.puts(output)
              IO.puts("✅ ClickHouse migration #{command} completed successfully")

            {output, exit_code} ->
              error_message = """
              ❌ ClickHouse migration #{command} failed with exit code #{exit_code}

              Database URL: #{database_url}
              Migrations Dir: #{migrations_dir}

              Output:
              #{output}

              Common issues:
              1. ClickHouse not running: docker-compose up -d clickhouse
              2. Wrong connection details in config
              3. Migration files not in correct goose format (-- +goose Up/Down)
              4. Check if ClickHouse supports the specific SQL syntax used
              """

              Mix.raise(error_message)
          end
        else
          _ ->
            Mix.raise("""
            ❌ Cannot connect to ClickHouse

            Please ensure:
            1. ClickHouse is running: docker-compose up -d clickhouse
            2. ClickHouse is accessible at #{config.hostname}:#{config.http_port}
            3. User '#{config.username}' has proper permissions
            """)
        end
    end
  end

  defp create_migration([_, name]) when is_binary(name) do
    case System.find_executable("goose") do
      nil ->
        Mix.raise("❌ goose executable not found in PATH")

      goose_path ->
        migrations_dir = Path.join([File.cwd!(), "priv", "clickhouse", "migrations"])

        goose_args = [
          "-dir",
          migrations_dir,
          "create",
          name,
          "sql"
        ]

        case System.cmd(goose_path, goose_args, stderr_to_stdout: true) do
          {output, 0} ->
            IO.puts(output)
            IO.puts("✅ Created new ClickHouse migration: #{name}")

          {output, _exit_code} ->
            Mix.raise("❌ Failed to create migration: #{output}")
        end
    end
  end

  defp create_migration(_) do
    Mix.raise("Usage: mix clickhouse.migrate create <migration_name>")
  end

  defp setup_database(config) do
    IO.puts("🚀 Setting up ClickHouse database...")

    # Test connection first
    case test_clickhouse_connection(config) do
      :ok ->
        # Create database if it doesn't exist
        create_database_if_needed(config)

        # Create migrations directory if it doesn't exist
        ensure_migrations_directory()

        # Run all migrations
        IO.puts("📦 Running all migrations...")
        run_migrate_command("up", config)

        IO.puts("✅ ClickHouse database setup completed successfully!")

      :error ->
        Mix.raise("""
        ❌ Cannot connect to ClickHouse for setup

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.hostname}:#{config.http_port}
        3. User '#{config.username}' has proper permissions
        """)
    end
  end

  defp reset_database(config) do
    IO.puts("🔥 Resetting ClickHouse database...")

    # Test connection first
    case test_clickhouse_connection(config) do
      :ok ->
        # Drop database
        drop_database(config)

        # Create database
        create_database_if_needed(config)

        # Create migrations directory if it doesn't exist
        ensure_migrations_directory()

        # Run all migrations
        IO.puts("📦 Running all migrations...")
        run_migrate_command("up", config)

        IO.puts("✅ ClickHouse database reset completed successfully!")

      :error ->
        Mix.raise("""
        ❌ Cannot connect to ClickHouse for reset

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.hostname}:#{config.http_port}
        3. User '#{config.username}' has proper permissions
        """)
    end
  end

  defp create_database_if_needed(config) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      IO.puts("📊 Creating database '#{database}' if it doesn't exist...")
      execute_clickhouse_query(config, "CREATE DATABASE IF NOT EXISTS #{database}")
    else
      IO.puts("📊 Using default database")
    end
  end

  defp drop_database(config) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      IO.puts("🗑️  Dropping database '#{database}'...")
      execute_clickhouse_query(config, "DROP DATABASE IF EXISTS #{database}")
    else
      IO.puts("⚠️  Cannot drop default database, skipping...")
    end
  end

  defp drop_database_command(config) do
    IO.puts("🗑️  Dropping ClickHouse database...")

    # Test connection first
    case test_clickhouse_connection(config) do
      :ok ->
        database = config[:database] || "oli_analytics_dev"

        if database != "default" do
          # Confirm the action with user
          IO.puts(
            "⚠️  WARNING: This will permanently delete the database '#{database}' and all its data!"
          )

          IO.puts("Are you sure you want to continue? (y/N)")

          case IO.gets("") |> String.trim() |> String.downcase() do
            response when response in ["y", "yes"] ->
              case execute_clickhouse_query(config, "DROP DATABASE IF EXISTS #{database}") do
                :ok ->
                  IO.puts("✅ Database '#{database}' dropped successfully")

                :error ->
                  Mix.raise("❌ Failed to drop database '#{database}'")
              end

            _ ->
              IO.puts("❌ Operation cancelled by user")
          end
        else
          Mix.raise("❌ Cannot drop the 'default' database - it's required by ClickHouse")
        end

      :error ->
        Mix.raise("""
        ❌ Cannot connect to ClickHouse for drop operation

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.hostname}:#{config.http_port}
        3. User '#{config.username}' has proper permissions
        """)
    end
  end

  defp ensure_migrations_directory do
    migrations_dir = Path.join([File.cwd!(), "priv", "clickhouse", "migrations"])

    unless File.exists?(migrations_dir) do
      IO.puts("📁 Creating migrations directory: #{migrations_dir}")
      File.mkdir_p!(migrations_dir)
    end
  end

  defp execute_clickhouse_query(config, query) do
    try do
      host = config[:hostname] || "localhost"
      http_port = config[:http_port] || 8123
      username = config[:username] || "default"
      password = config[:password] || "clickhouse"

      url = "http://#{username}:#{password}@#{host}:#{http_port}/"

      case HTTPoison.post(url, query, [], timeout: 10000, recv_timeout: 10000) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          IO.puts("✅ Query executed successfully")
          :ok

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          IO.puts("⚠️  Query responded with status #{code}: #{body}")
          :ok

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.puts("❌ Query execution failed: #{reason}")
          :error
      end
    rescue
      e ->
        IO.puts("❌ Query execution failed: #{inspect(e)}")
        :error
    end
  end

  defp build_database_url(config) do
    host = config[:hostname]
    # goose uses TCP port for ClickHouse, not HTTP
    port = 9090
    username = config[:username]
    password = config[:password]
    database = config[:database]

    "tcp://#{username}:#{password}@#{host}:#{port}/#{database}"
  end

  defp test_clickhouse_connection(config) do
    try do
      # Use HTTP port for connection test
      host = config[:hostname]
      http_port = config[:http_port]
      username = config[:username]
      password = config[:password]

      url = "http://#{username}:#{password}@#{host}:#{http_port}/"

      case HTTPoison.post(url, "SELECT 1", [], timeout: 5000, recv_timeout: 5000) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          IO.puts("✅ ClickHouse connection successful")
          :ok

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          IO.puts("⚠️  ClickHouse responded with status #{code}: #{body}")
          :ok

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.puts("❌ ClickHouse connection failed: #{reason}")
          :error
      end
    rescue
      e ->
        IO.puts("❌ ClickHouse connection test failed: #{inspect(e)}")
        :error
    end
  end
end

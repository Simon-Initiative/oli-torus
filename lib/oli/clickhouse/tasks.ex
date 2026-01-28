defmodule Oli.ClickHouse.Tasks do
  @moduledoc """
  Used for executing ClickHouse release tasks when run in production without Mix
  installed.
  """
  @app :oli

  def up do
    config = load_clickhouse_config()
    IO.puts("Running ClickHouse migrations...")
    run_migrate_command("up", config)
  end

  def down do
    config = load_clickhouse_config()
    IO.puts("Rolling back ClickHouse migration...")
    run_migrate_command("down", config)
  end

  def status do
    config = load_clickhouse_config()
    IO.puts("Checking ClickHouse migration status...")
    run_migrate_command("status", config)
  end

  def create(name) when is_binary(name) do
    IO.puts("Creating new ClickHouse migration...")
    create_migration(name)
  end

  def setup do
    config = load_clickhouse_config()
    IO.puts("Setting up ClickHouse database...")
    setup_database(config)
  end

  def reset do
    config = load_clickhouse_config()
    IO.puts("Resetting ClickHouse database...")
    reset_database(config)
  end

  def drop do
    config = load_clickhouse_config()
    IO.puts("Dropping ClickHouse database...")
    drop_database_command(config)
  end

  def reset(%{dangerously_force: true}) do
    config = load_clickhouse_config()
    reset_database_force(config)
  end

  def drop(%{dangerously_force: true}) do
    config = load_clickhouse_config()
    drop_database_force(config)
  end

  defp load_clickhouse_config do
    load_app()
    config = Application.get_env(:oli, :clickhouse)

    if config do
      config |> Enum.into(%{})
    else
      raise "ClickHouse configuration not found. Please ensure :clickhouse config is set in :oli application."
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

        raise error_message

      goose_path ->
        database_url = build_database_url(config)
        migrations_dir = get_migrations_directory()

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
              :ok

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

              raise error_message
          end
        else
          _ ->
            raise """
            ❌ Cannot connect to ClickHouse

            Please ensure:
            1. ClickHouse is running: docker-compose up -d clickhouse
            2. ClickHouse is accessible at #{config.host}:#{config.native_port}
            3. User '#{config.user}' has proper permissions
            """
        end
    end
  end

  defp create_migration(name) when is_binary(name) do
    case System.find_executable("goose") do
      nil ->
        raise "❌ goose executable not found in PATH"

      goose_path ->
        migrations_dir = get_migrations_directory()

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
            :ok

          {output, _exit_code} ->
            raise "❌ Failed to create migration: #{output}"
        end
    end
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
        :ok

      :error ->
        raise """
        ❌ Cannot connect to ClickHouse for setup

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """
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
        :ok

      :error ->
        raise """
        ❌ Cannot connect to ClickHouse for reset

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """
    end
  end

  defp reset_database_force(config) do
    IO.puts("🔥 Forcefully resetting ClickHouse database...")

    # Test connection first
    case test_clickhouse_connection(config) do
      :ok ->
        # Drop database without confirmation
        drop_database_force(config)

        # Create database
        create_database_if_needed(config)

        # Create migrations directory if it doesn't exist
        ensure_migrations_directory()

        # Run all migrations
        IO.puts("📦 Running all migrations...")
        run_migrate_command("up", config)

        IO.puts("✅ ClickHouse database reset completed successfully!")
        :ok

      :error ->
        raise """
        ❌ Cannot connect to ClickHouse for reset

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """
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
                  :ok

                :error ->
                  raise "❌ Failed to drop database '#{database}'"
              end

            _ ->
              IO.puts("❌ Operation cancelled by user")
              :cancelled
          end
        else
          raise "❌ Cannot drop the 'default' database - it's required by ClickHouse"
        end

      :error ->
        raise """
        ❌ Cannot connect to ClickHouse for drop operation

        Please ensure:
        1. ClickHouse is running: docker-compose up -d clickhouse
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """
    end
  end

  defp drop_database_force(config) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      IO.puts("🗑️  Force dropping database '#{database}'...")

      case execute_clickhouse_query(config, "DROP DATABASE IF EXISTS #{database}") do
        :ok ->
          IO.puts("✅ Database '#{database}' dropped successfully")
          :ok

        :error ->
          raise "❌ Failed to drop database '#{database}'"
      end
    else
      IO.puts("⚠️  Cannot drop default database, skipping...")
      :ok
    end
  end

  defp create_database_if_needed(config) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      IO.puts("📊 Creating database '#{database}' if it doesn't exist...")
      execute_clickhouse_query(config, "CREATE DATABASE IF NOT EXISTS #{database}")
    else
      IO.puts("📊 Using default database")
      :ok
    end
  end

  defp drop_database(config) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      IO.puts("🗑️  Dropping database '#{database}'...")
      execute_clickhouse_query(config, "DROP DATABASE IF EXISTS #{database}")
    else
      IO.puts("⚠️  Cannot drop default database, skipping...")
      :ok
    end
  end

  defp get_migrations_directory do
    case :code.priv_dir(@app) do
      {:error, :bad_name} ->
        # Fallback for development/mix environment
        Path.join([File.cwd!(), "clickhouse", "migrations"])

      priv_dir ->
        # Production environment
        Path.join([priv_dir, "clickhouse", "migrations"])
    end
  end

  defp ensure_migrations_directory do
    migrations_dir = get_migrations_directory()

    unless File.exists?(migrations_dir) do
      IO.puts("📁 Creating migrations directory: #{migrations_dir}")
      File.mkdir_p!(migrations_dir)
    end
  end

  defp execute_clickhouse_query(config, query) do
    try do
      host = config[:host] || "localhost"
      port = config[:http_port] || 8123
      user = config[:user] || "default"
      password = config[:password] || "clickhouse"

      url = "http://#{user}:#{password}@#{host}:#{port}/"

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
    host = config[:host]
    # goose uses TCP port for ClickHouse, not HTTP
    port = config[:native_port]
    user = config[:user]
    password = config[:password]
    database = config[:database]

    "tcp://#{user}:#{password}@#{host}:#{port}/#{database}"
  end

  defp test_clickhouse_connection(config) do
    try do
      # Use HTTP port for connection test
      host = config[:host]
      port = config[:http_port]
      user = config[:user]
      password = config[:password]

      url = "http://#{user}:#{password}@#{host}:#{port}/"

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

  @spec load_app() :: :ok | {:error, term()}
  defp load_app do
    Application.load(@app)
    Application.ensure_all_started(:httpoison)
  end
end

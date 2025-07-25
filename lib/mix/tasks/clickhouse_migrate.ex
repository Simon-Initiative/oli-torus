defmodule Mix.Tasks.Clickhouse.Migrate do
  @moduledoc """
  Manage ClickHouse migrations using goose.

  Available commands:
    mix clickhouse.migrate status  # Show migration status
    mix clickhouse.migrate up      # Run pending migrations
    mix clickhouse.migrate down    # Rollback one migration
    mix clickhouse.migrate create <name>  # Create new migration
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

    config = get_clickhouse_config()

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

      _ ->
        Mix.raise("Unknown command: #{command}. Available commands: up, down, status, create")
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

  defp build_database_url(config) do
    host = config[:hostname] || "localhost"
    # goose uses TCP port for ClickHouse, not HTTP
    port = 9090
    username = config[:username] || "default"
    password = config[:password] || "clickhouse"
    database = config[:database] || "default"

    "tcp://#{username}:#{password}@#{host}:#{port}/#{database}"
  end

  defp get_clickhouse_config do
    %{
      hostname: Application.get_env(:oli, :clickhouse_host, "localhost"),
      # HTTP port for connection test
      http_port: Application.get_env(:oli, :clickhouse_port, 8123),
      username: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, "clickhouse"),
      database: Application.get_env(:oli, :clickhouse_database, "default")
    }
  end

  defp test_clickhouse_connection(config) do
    try do
      # Use HTTP port for connection test
      host = config[:hostname] || "localhost"
      http_port = config[:http_port] || 8123
      username = config[:username] || "default"
      password = config[:password] || "clickhouse"

      url = "http://#{username}:#{password}@#{host}:#{http_port}/"

      case HTTPoison.post(url, "SELECT 1", [], timeout: 5000, recv_timeout: 5000) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          IO.puts("✅ ClickHouse connection test successful")
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

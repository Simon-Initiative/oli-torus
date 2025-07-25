defmodule Mix.Tasks.Clickhouse.Migrate do
  @moduledoc """
  Runs ClickHouse migrations using dbmate.

  This task provides a convenient way to manage ClickHouse migrations
  from within the Elixir application during development and deployment.

  ## Examples

      mix clickhouse.migrate
      mix clickhouse.migrate up
      mix clickhouse.migrate down
      mix clickhouse.migrate status

  """

  use Mix.Task
  require Logger

  @shortdoc "Runs ClickHouse migrations using dbmate"

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
        Logger.info("Running ClickHouse migrations...")
        run_dbmate_command("up", config)

      "down" ->
        Logger.info("Rolling back ClickHouse migration...")
        run_dbmate_command("down", config)

      "status" ->
        Logger.info("Checking ClickHouse migration status...")
        run_dbmate_command("status", config)

      "create" ->
        Logger.info("Creating ClickHouse database...")
        run_dbmate_command("create", config)

      "drop" ->
        Logger.info("Dropping ClickHouse database...")
        run_dbmate_command("drop", config)

      _ ->
        Logger.error("Unknown command: #{command}")
        Logger.info("Available commands: up, down, status, create, drop")
        System.halt(1)
    end
  end

  defp run_dbmate_command(command, config) do
    database_url = build_database_url(config)
    migrations_dir = Path.join([File.cwd!(), "priv", "clickhouse", "migrations"])

    env = [
      {"DATABASE_URL", database_url},
      {"DBMATE_MIGRATIONS_DIR", "/db/migrations"},
      {"DBMATE_NO_DUMP_SCHEMA", "true"}
    ]

    docker_args =
      [
        "run",
        "--rm",
        "--network",
        "oli-torus_default",
        "-v",
        "#{migrations_dir}:/db/migrations"
      ] ++
        Enum.flat_map(env, fn {k, v} -> ["-e", "#{k}=#{v}"] end) ++
        ["amacneil/dbmate:latest", command]

    case System.cmd("docker", docker_args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info(output)
        Logger.info("✅ ClickHouse migration #{command} completed successfully")

      {output, exit_code} ->
        Logger.error("❌ ClickHouse migration #{command} failed with exit code #{exit_code}")
        Logger.error(output)
        System.halt(exit_code)
    end
  end

  defp build_database_url(config) do
    user = config.user || "default"
    password = if config.password && config.password != "", do: ":#{config.password}", else: ""
    host = String.replace(config.host || "http://localhost", ~r/^https?:\/\//, "")
    port = config.port || 8123
    database = config.database || "default"

    "clickhouse://#{user}#{password}@#{host}:#{port}/#{database}"
  end

  defp get_clickhouse_config do
    %{
      host: Application.get_env(:oli, :clickhouse_host, "localhost"),
      port: Application.get_env(:oli, :clickhouse_port, 8123),
      user: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, ""),
      database: Application.get_env(:oli, :clickhouse_database, "default")
    }
  end
end

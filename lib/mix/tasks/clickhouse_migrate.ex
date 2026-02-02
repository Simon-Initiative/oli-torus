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

  @shortdoc "Manage ClickHouse migrations using mix"

  @doc false
  def run(args) do
    Mix.Task.run("app.start")

    command =
      case args do
        [] -> "up"
        [cmd] -> cmd
        [cmd | _] -> cmd
      end

    try do
      case command do
        "up" ->
          Oli.ClickHouse.Tasks.up()

        "down" ->
          Oli.ClickHouse.Tasks.down()

        "status" ->
          Oli.ClickHouse.Tasks.status()

        "create" ->
          case args do
            [_, name] when is_binary(name) ->
              Oli.ClickHouse.Tasks.create(name)

            _ ->
              Mix.raise("Usage: mix clickhouse.migrate create <migration_name>")
          end

        "setup" ->
          Oli.ClickHouse.Tasks.setup()

        "reset" ->
          Oli.ClickHouse.Tasks.reset()

        "drop" ->
          Oli.ClickHouse.Tasks.drop()

        _ ->
          Mix.raise(
            "Unknown command: #{command}. Available commands: up, down, status, create, setup, reset, drop"
          )
      end
    rescue
      e ->
        Mix.raise(Exception.message(e))
    end
  end
end

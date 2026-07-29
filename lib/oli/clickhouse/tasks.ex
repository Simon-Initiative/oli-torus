defmodule Oli.Clickhouse.Tasks do
  @moduledoc """
  Used for executing ClickHouse release tasks when run in production without Mix
  installed.
  """

  @app :oli

  @type event_sink :: (map() -> term())

  def run(kind, opts \\ [])
  def run(:setup, opts), do: setup(opts)
  def run(:migrate_up, opts), do: up(opts)
  def run(:migrate_down, opts), do: down(opts)
  def run(:status, opts), do: status(opts)
  def run({:create, name}, opts), do: create(name, opts)
  def run(:drop, opts), do: drop(opts)
  def run(:reset, opts), do: reset(opts)

  def up(opts \\ []) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    emit(sink, :info, "Running ClickHouse migrations...")
    run_migrate_command("up", config, sink)
  end

  def down(opts \\ []) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    emit(sink, :info, "Rolling back ClickHouse migration...")
    run_migrate_command("down", config, sink)
  end

  def status(opts \\ []) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    emit(sink, :info, "Checking ClickHouse migration status...")
    run_migrate_command("status", config, sink)
  end

  def create(name, opts \\ []) when is_binary(name) do
    sink = event_sink(opts)
    emit(sink, :info, "Creating new ClickHouse migration...")
    create_migration(name, sink)
  end

  def setup(opts \\ []) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    setup_database(config, sink)
  end

  def reset(opts \\ []) when is_list(opts) do
    sink = event_sink(opts)

    emit(
      sink,
      :warning,
      "WARNING! This will completely erase all data from the ClickHouse database."
    )

    emit(
      sink,
      :warning,
      "THIS IS A DANGEROUS AND PERMANENT OPERATION WHICH WILL RESULT IN DATA LOSS"
    )

    confirm =
      IO.gets(
        "Are you sure you want to continue? (Enter RESET CLICKHOUSE to continue, or use --force to bypass): "
      )

    if normalize_confirmation(confirm) == "RESET CLICKHOUSE" do
      reset(%{dangerously_force: true}, opts)
    else
      emit(sink, :warning, "ABORTED: Operation was not confirmed by user.")
      :cancelled
    end
  end

  def drop(opts \\ []) when is_list(opts) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    emit(sink, :info, "Dropping ClickHouse database...")
    drop_database(config, sink)
  end

  def reset(%{dangerously_force: true}, opts) when is_list(opts) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    reset_database(config, sink, force?: true)
  end

  def drop(%{dangerously_force: true}, opts) when is_list(opts) do
    config = load_clickhouse_config()
    sink = event_sink(opts)
    drop_database(config, sink, force?: true)
  end

  defp load_clickhouse_config do
    load_app()
    config = Application.get_env(:oli, :clickhouse)

    if config do
      config = Enum.into(config, %{})

      config
      |> Map.put(:user, Map.fetch!(config, :admin_user))
      |> Map.put(:password, Map.fetch!(config, :admin_password))
    else
      raise "ClickHouse configuration not found. Please ensure :clickhouse config is set in :oli application."
    end
  end

  defp normalize_confirmation(nil), do: ""
  defp normalize_confirmation(value), do: value |> String.trim() |> String.upcase()

  defp run_migrate_command(command, config, sink) do
    database = configured_database!(config)

    case System.find_executable("goose") do
      nil ->
        error_message = """
        goose executable not found in PATH

        Please install goose:
          macOS: brew install goose
          Linux: go install github.com/pressly/goose/v3/cmd/goose@latest
          Or visit: https://github.com/pressly/goose
        """

        emit(sink, :error, error_message)
        raise error_message

      goose_path ->
        database_url = build_database_url(config, database)
        migrations_dir = get_migrations_directory()

        emit(sink, :info, "Target database: #{database}")
        emit(sink, :info, "Migrations directory: #{migrations_dir}")

        with :ok <- test_clickhouse_connection(config, sink, database: database) do
          goose_args = ["-dir", migrations_dir, "clickhouse", database_url, command]

          case System.cmd(goose_path, goose_args, stderr_to_stdout: true) do
            {output, 0} ->
              maybe_emit_command_output(sink, redact_credentials(output, config))
              emit(sink, :success, "ClickHouse migration #{command} completed successfully")
              :ok

            {output, exit_code} ->
              safe_output = redact_credentials(output, config)
              safe_endpoint = clickhouse_native_endpoint(config, database)

              error_message = """
              ClickHouse migration #{command} failed with exit code #{exit_code}

              Target: #{safe_endpoint}
              Migrations Dir: #{migrations_dir}

              Output:
              #{safe_output}

              Common issues:
              1. ClickHouse is not running or accepting connections
              2. Wrong connection details in config
              3. Migration files not in correct goose format (-- +goose Up/Down)
              4. Check if ClickHouse supports the specific SQL syntax used
              """

              emit(sink, :error, error_message)
              raise error_message
          end
        else
          _ ->
            error_message = """
            Cannot connect to ClickHouse

            Please ensure:
            1. ClickHouse is running and accepting connections
            2. ClickHouse is accessible at #{config.host}:#{config.native_port}
            3. User '#{config.user}' has proper permissions
            """

            emit(sink, :error, error_message)
            raise error_message
        end
    end
  end

  defp create_migration(name, sink) when is_binary(name) do
    case System.find_executable("goose") do
      nil ->
        error_message = "goose executable not found in PATH"
        emit(sink, :error, error_message)
        raise error_message

      goose_path ->
        migrations_dir = get_migrations_directory()
        goose_args = ["-dir", migrations_dir, "create", name, "sql"]

        case System.cmd(goose_path, goose_args, stderr_to_stdout: true) do
          {output, 0} ->
            maybe_emit_command_output(sink, output)
            emit(sink, :success, "Created new ClickHouse migration: #{name}")
            :ok

          {output, _exit_code} ->
            error_message = "Failed to create migration: #{output}"
            emit(sink, :error, error_message)
            raise error_message
        end
    end
  end

  defp setup_database(config, sink) do
    emit(sink, :info, "Setting up ClickHouse database...")

    case test_clickhouse_connection(config, sink) do
      :ok ->
        with :ok <- create_database_if_needed(config, sink) do
          ensure_migrations_directory(sink)
          emit(sink, :info, "Running all migrations...")
          run_migrate_command("up", config, sink)
          emit(sink, :success, "ClickHouse database setup completed successfully!")
          :ok
        else
          :error ->
            error_message = "Failed to create ClickHouse database before setup"
            emit(sink, :error, error_message)
            raise error_message
        end

      :error ->
        error_message = """
        Cannot connect to ClickHouse for setup

        Please ensure:
        1. ClickHouse is running and accepting connections
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """

        emit(sink, :error, error_message)
        raise error_message
    end
  end

  defp reset_database(config, sink, opts) do
    force? = Keyword.get(opts, :force?, false)
    emit(sink, :warning, "Resetting ClickHouse database...")

    case test_clickhouse_connection(config, sink) do
      :ok ->
        with :ok <- drop_database(config, sink, force?: force?),
             :ok <- create_database_if_needed(config, sink) do
          ensure_migrations_directory(sink)
          emit(sink, :info, "Running all migrations...")
          run_migrate_command("up", config, sink)
          emit(sink, :success, "ClickHouse database reset completed successfully!")
          :ok
        else
          :error ->
            error_message =
              if force? do
                "Failed to force reset ClickHouse database because the drop or create step did not succeed"
              else
                "Failed to reset ClickHouse database because the drop or create step did not succeed"
              end

            emit(sink, :error, error_message)
            raise error_message
        end

      :error ->
        error_message = """
        Cannot connect to ClickHouse for reset

        Please ensure:
        1. ClickHouse is running and accepting connections
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """

        emit(sink, :error, error_message)
        raise error_message
    end
  end

  defp drop_database(config, sink, opts \\ []) do
    force? = Keyword.get(opts, :force?, false)
    emit(sink, :warning, "Dropping ClickHouse database...")

    case test_clickhouse_connection(config, sink) do
      :ok ->
        database = config[:database] || "oli_analytics_dev"

        if database != "default" do
          if force? or confirm_drop_database?(database) do
            case execute_clickhouse_query(config, "DROP DATABASE IF EXISTS #{database}", sink) do
              :ok ->
                emit(sink, :success, "Database '#{database}' dropped successfully")
                :ok

              :error ->
                error_message = "Failed to drop database '#{database}'"
                emit(sink, :error, error_message)
                raise error_message
            end
          else
            emit(sink, :warning, "Operation cancelled by user")
            :cancelled
          end
        else
          if force? do
            emit(sink, :warning, "Cannot drop default database, skipping...")
            :ok
          else
            error_message = "Cannot drop the 'default' database - it's required by ClickHouse"
            emit(sink, :error, error_message)
            raise error_message
          end
        end

      :error ->
        error_message = """
        Cannot connect to ClickHouse for drop operation

        Please ensure:
        1. ClickHouse is running and accepting connections
        2. ClickHouse is accessible at #{config.host}:#{config.http_port}
        3. User '#{config.user}' has proper permissions
        """

        emit(sink, :error, error_message)
        raise error_message
    end
  end

  defp confirm_drop_database?(database) do
    IO.puts(
      "WARNING: This will permanently delete the database '#{database}' and all its data!"
    )

    IO.puts("Are you sure you want to continue? (y/N)")

    case IO.gets("") |> String.trim() |> String.downcase() do
      response when response in ["y", "yes"] -> true
      _ -> false
    end
  end

  defp create_database_if_needed(config, sink) do
    database = config[:database] || "oli_analytics_dev"

    if database != "default" do
      emit(sink, :info, "Creating database '#{database}' if it doesn't exist...")
      execute_clickhouse_query(config, "CREATE DATABASE IF NOT EXISTS #{database}", sink)
    else
      emit(sink, :info, "Using default database")
      :ok
    end
  end

  defp get_migrations_directory do
    case :code.priv_dir(@app) do
      {:error, :bad_name} ->
        Path.join([File.cwd!(), "clickhouse", "migrations"])

      priv_dir ->
        Path.join([priv_dir, "clickhouse", "migrations"])
    end
  end

  defp ensure_migrations_directory(sink) do
    migrations_dir = get_migrations_directory()

    unless File.exists?(migrations_dir) do
      emit(sink, :info, "Creating migrations directory: #{migrations_dir}")
      File.mkdir_p!(migrations_dir)
    end
  end

  defp execute_clickhouse_query(config, query, sink) do
    try do
      user = config[:user]
      password = config[:password]
      url = clickhouse_http_url(config)

      case HTTPoison.post(url, query, [],
             timeout: 10_000,
             recv_timeout: 10_000,
             hackney: [basic_auth: {user, password}]
           ) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          emit(sink, :success, "Query executed successfully")
          :ok

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          emit(sink, :warning, "Query responded with status #{code}: #{body}")
          :error

        {:error, %HTTPoison.Error{reason: reason}} ->
          emit(sink, :error, "Query execution failed: #{reason}")
          :error
      end
    rescue
      e ->
        emit(sink, :error, "Query execution failed: #{inspect(e)}")
        :error
    end
  end

  defp build_database_url(config, database) do
    host = clickhouse_host(config)
    port = config[:native_port]
    user = config[:user]
    password = config[:password]

    "tcp://#{user}:#{password}@#{host}:#{port}/#{database}"
  end

  @doc false
  def clickhouse_native_endpoint(config, database) do
    "tcp://#{clickhouse_host(config)}:#{config[:native_port]}/#{database}"
  end

  defp configured_database!(config) do
    case config[:database] do
      database when is_binary(database) ->
        case String.trim(database) do
          "" -> raise "ClickHouse database is not configured"
          configured_database -> configured_database
        end

      _ ->
        raise "ClickHouse database is not configured"
    end
  end

  @doc false
  def clickhouse_http_url(config, opts \\ []) do
    host =
      config
      |> Map.get(:host, "localhost")
      |> to_string()
      |> String.trim()

    base_url =
      case URI.parse(host) do
        %URI{scheme: scheme} when scheme in ["http", "https"] -> host
        _ -> "http://" <> host
      end

    database = Keyword.get(opts, :database)

    query =
      case database do
        nil -> nil
        database -> URI.encode_query(%{"database" => database})
      end

    base_url
    |> URI.parse()
    |> Map.put(:userinfo, nil)
    |> Map.put(:port, config[:http_port] || 8123)
    |> Map.put(:path, "/")
    |> Map.put(:query, query)
    |> Map.put(:fragment, nil)
    |> URI.to_string()
  end

  defp clickhouse_host(config) do
    host =
      config
      |> Map.fetch!(:host)
      |> to_string()
      |> String.trim()

    uri =
      case URI.parse(host) do
        %URI{scheme: scheme} = uri when scheme in ["http", "https", "tcp"] -> uri
        _ -> URI.parse("//" <> host)
      end

    uri.host || raise "ClickHouse host is not configured"
  end

  defp redact_credentials(output, config) when is_binary(output) do
    [:admin_password, :query_password, :password]
    |> Enum.map(&config[&1])
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
    |> Enum.reduce(output, &String.replace(&2, &1, "[REDACTED]"))
  end

  defp test_clickhouse_connection(config, sink, opts \\ []) do
    try do
      user = config[:user]
      password = config[:password]
      database = Keyword.get(opts, :database)
      url = clickhouse_http_url(config, database: database)

      case HTTPoison.post(url, "SELECT 1", [],
             timeout: 5_000,
             recv_timeout: 5_000,
             hackney: [basic_auth: {user, password}]
           ) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          emit(sink, :success, "ClickHouse connection successful")
          :ok

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          emit(sink, :warning, "ClickHouse responded with status #{code}: #{body}")
          :ok

        {:error, %HTTPoison.Error{reason: reason}} ->
          emit(sink, :error, "ClickHouse connection failed: #{reason}")
          :error
      end
    rescue
      e ->
        emit(sink, :error, "ClickHouse connection test failed: #{inspect(e)}")
        :error
    end
  end

  defp event_sink(opts), do: Keyword.get(opts, :sink, default_sink())

  defp default_sink do
    fn %{message: message} -> IO.puts(message) end
  end

  defp emit(sink, level, message, metadata \\ %{}) when is_function(sink, 1) do
    sink.(%{level: level, message: message, metadata: metadata})
  end

  defp maybe_emit_command_output(_sink, output) when output in [nil, ""], do: :ok

  defp maybe_emit_command_output(sink, output) when is_binary(output) do
    case String.trim(output) do
      "" -> :ok
      trimmed -> emit(sink, :info, trimmed)
    end
  end

  defp load_app do
    Application.load(@app)
    Application.ensure_all_started(:httpoison)
  end
end

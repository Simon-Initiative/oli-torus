# Rehearses the settings_changes conversion migration on a newly created disposable database:
# conversion, reconciliation, rollback, roll-forward, restart after a partial run, and a forced
# reconciliation failure. Records durations, WAL bytes, locks, and how long a concurrent read of
# audit_log_events waits. Never reuses or drops an existing database.
#
#   MIX_ENV=test mix run --no-start test/support/settings_changes_conversion_rehearsal.exs
#
# The database is built with the repository migrations up to the one before the audit log
# partitioning, so that migration creates the partitions from the oldest history row, as in
# production. Some of those migrations call Oli.Repo, so the rehearsal starts Oli.Repo itself
# against the disposable database. SETTINGS_REHEARSAL_ROWS sets the synthetic history volume
# (default: production on 2026-10-29).
defmodule SettingsChangesRehearsal do
  @before_partitioning 20_261_028_171_543
  @partitioning 20_261_030_155_349
  @version 20_261_119_193_918
  @migration Oli.Repo.Migrations.ConvertSettingsChangesToAuditEvents
  @plan_b_seconds 60
  @secret_marker "SECRET-REHEARSAL-VALUE"

  def run(repo, conn_config, rows) do
    Ecto.Migrator.run(repo, "priv/repo/migrations", :up, to: @before_partitioning, log: false)
    load_history(repo, rows)
    original = snapshot(repo)
    sql(repo, "VACUUM ANALYZE settings_changes")

    [[history_size]] =
      rows(repo, "SELECT pg_size_pretty(pg_total_relation_size('settings_changes'))")

    Process.put(:history_size, history_size)
    Ecto.Migrator.run(repo, "priv/repo/migrations", :up, to: @partitioning, log: false)

    up = measure(repo, conn_config, "up", fn -> migrate(repo, :up) end)
    verify_conversion(repo, length(original))
    size = converted_size(repo)

    down = measure(repo, conn_config, "down", fn -> migrate(repo, :down) end)
    verify_rollback(repo, original)

    roll_forward = measure(repo, conn_config, "roll-forward", fn -> migrate(repo, :up) end)
    verify_conversion(repo, length(original))

    migrate(repo, :down)
    restart_after_partial_run(repo, length(original))

    migrate(repo, :down)
    forced_reconciliation_failure(repo, length(original))

    report(repo, rows, size, [up, down, roll_forward])
  end

  # Bulk rows over the production date range (2024-07-29 to 2026-10-29) with gaps between IDs:
  # both user types, missing accounts (no account rows exist), one password change in twenty,
  # null old values, and a few unknown user types; plus rows on half-year boundaries.
  defp load_history(repo, rows) do
    sql(repo, """
    INSERT INTO resources (id, inserted_at, updated_at)
    SELECT g, now(), now() FROM generate_series(1, 200) g
    """)

    sql(repo, """
    INSERT INTO sections (id, title, slug, inserted_at, updated_at)
    SELECT g, 'Section ' || g, 'section-' || g, now(), now() FROM generate_series(1, 100) g
    """)

    sql(repo, """
    INSERT INTO settings_changes
      (id, resource_id, section_id, user_id, user_type, key, old_value, new_value,
       inserted_at, updated_at)
    SELECT g * 2 + 100,
           g % 200 + 1,
           g % 100 + 1,
           g % 5000 + 1,
           CASE WHEN g % 997 = 0 THEN NULL WHEN g % 3 = 0 THEN 'author' ELSE 'instructor' END,
           CASE WHEN g % 20 = 0 THEN 'password'
                ELSE (ARRAY['max_attempts', 'end_date', 'late_submit', 'time_limit'])[g % 4 + 1]
           END,
           CASE WHEN g % 20 = 0 THEN '#{@secret_marker}-old-' || g
                WHEN g % 7 = 0 THEN NULL
                ELSE 'old ' || g END,
           CASE WHEN g % 20 = 0 THEN '#{@secret_marker}-new-' || g ELSE 'new ' || g END,
           ts, ts
    FROM generate_series(1, #{rows}) g,
         LATERAL (SELECT timestamptz '2024-07-29 10:00:00+00'
           + (timestamptz '2026-10-29 00:00:00+00' - timestamptz '2024-07-29 10:00:00+00')
             * g / #{rows} AS ts) t
    """)

    edge = rows * 2 + 1_000

    sql(repo, """
    INSERT INTO settings_changes
      (id, resource_id, section_id, user_id, user_type, key, old_value, new_value,
       inserted_at, updated_at)
    VALUES
      (#{edge + 1}, 1, 1, 1, 'author', 'max_attempts', '1', '2',
       '2024-12-31 23:59:59.999999+00', '2024-12-31 23:59:59.999999+00'),
      (#{edge + 2}, 1, 1, 1, 'instructor', 'max_attempts', '2', '3',
       '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'),
      (#{edge + 3}, 1, 1, 1, 'instructor', 'end_date', NULL, NULL,
       '2025-07-01 00:00:00+00', '2025-07-01 00:00:00+00')
    """)
  end

  defp snapshot(repo) do
    rows(repo, """
    SELECT id, resource_id, section_id, user_id, user_type, key, old_value, new_value, inserted_at
    FROM settings_changes ORDER BY id
    """)
  end

  defp verify_conversion(repo, expected) do
    check("settings_changes is dropped", not exists?(repo, "settings_changes"))
    check("every history row has one converted row", converted(repo) == expected)

    check(
      "no password value reaches audit_log_events",
      rows(repo, "SELECT count(*) FROM audit_log_events WHERE changes::text LIKE $1", [
        "%#{@secret_marker}%"
      ]) == [[0]]
    )

    check(
      "password changes keep the redaction marker",
      rows(repo, """
      SELECT count(*) FROM audit_log_events
      WHERE legacy_source = 'settings_changes' AND changes->'password'->>'redacted' = 'true'
      """) != [[0]]
    )

    check(
      "unknown user types keep the account in details",
      rows(repo, """
      SELECT count(*) FROM audit_log_events
      WHERE legacy_source = 'settings_changes' AND actor_type = 'unknown'
        AND details ? 'legacy_user_id'
      """) != [[0]]
    )
  end

  # Every row comes back with its ID and values, except password values, which are redacted.
  defp verify_rollback(repo, original) do
    check("no converted row remains after rollback", converted(repo) == 0)

    redact = fn [id, resource, section, user, type, key, old, new, at] ->
      case key do
        "password" -> [id, resource, section, user, type, key, "[redacted]", "[redacted]", at]
        _key -> [id, resource, section, user, type, key, old, new, at]
      end
    end

    check("rollback restores every history row", snapshot(repo) == Enum.map(original, redact))

    [[next_id]] =
      rows(repo, """
      INSERT INTO settings_changes (key, inserted_at, updated_at)
      VALUES ('max_attempts', now(), now()) RETURNING id
      """)

    check(
      "the restored sequence continues after the restored IDs",
      next_id > List.last(Enum.map(original, &hd/1))
    )

    sql(repo, "DELETE FROM settings_changes WHERE id = $1", [next_id])
  end

  defp restart_after_partial_run(repo, expected) do
    sql(repo, """
    INSERT INTO audit_log_events (inserted_at, schema_version, event_type, actor_type,
      legacy_source, legacy_id)
    SELECT inserted_at, 1, 'assessment_setting_changed', 'unknown', 'settings_changes', id
    FROM settings_changes ORDER BY id LIMIT 1000
    """)

    migrate(repo, :up)
    check("a restarted conversion does not duplicate converted rows", converted(repo) == expected)
  end

  defp forced_reconciliation_failure(repo, expected) do
    sql(repo, """
    INSERT INTO audit_log_events (inserted_at, schema_version, event_type, actor_type,
      legacy_source, legacy_id)
    VALUES (now(), 1, 'assessment_setting_changed', 'unknown', 'settings_changes', -1)
    """)

    failed =
      try do
        migrate(repo, :up)
        false
      rescue
        _error -> true
      end

    check("an unreconciled conversion fails", failed)
    check("a failed conversion keeps settings_changes", exists?(repo, "settings_changes"))
    check("a failed conversion writes nothing", converted(repo) == 1)

    repo.transaction(fn ->
      sql(repo, "SET LOCAL oli.audit_log_allow_mutation = 'on'")
      sql(repo, "DELETE FROM audit_log_events WHERE legacy_id = -1")
    end)

    migrate(repo, :up)
    check("the conversion succeeds once the stray row is removed", converted(repo) == expected)
  end

  defp converted(repo) do
    [[count]] =
      rows(repo, """
      SELECT count(*) FROM audit_log_events
      WHERE schema_version = 1 AND legacy_source = 'settings_changes'
      """)

    count
  end

  defp migrate(repo, direction) do
    :ok = apply(Ecto.Migrator, direction, [repo, @version, @migration, [log: false]])
  end

  # While the step runs, one connection polls pg_locks and another keeps reading
  # audit_log_events, as the application would, to record the longest wait.
  defp measure(repo, conn_config, label, fun) do
    [[lsn_before]] = rows(repo, "SELECT pg_current_wal_lsn()::text")
    poller = start_lock_poller(conn_config)
    reader = start_reader(conn_config)
    {micros, _} = :timer.tc(fun)
    send(poller, {:stop, self()})
    send(reader, {:stop, self()})

    locks =
      receive do
        {:locks, locks} -> locks
      end

    max_wait =
      receive do
        {:max_wait, max_wait} -> max_wait
      end

    [[wal_bytes]] =
      rows(repo, "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), $1::text::pg_lsn)::bigint", [
        lsn_before
      ])

    %{
      label: label,
      seconds: micros / 1_000_000,
      wal_bytes: wal_bytes,
      locks: locks,
      max_read_wait_ms: div(max_wait, 1_000)
    }
  end

  defp start_lock_poller(conn_config) do
    {:ok, conn} = Postgrex.start_link(conn_config)
    spawn_link(fn -> poll_locks(conn, MapSet.new()) end)
  end

  defp poll_locks(conn, seen) do
    %{rows: rows} =
      Postgrex.query!(
        conn,
        """
        SELECT DISTINCT COALESCE(c.relname, 'new relations'), l.mode
        FROM pg_locks l LEFT JOIN pg_class c ON c.oid = l.relation
        WHERE l.granted AND l.pid <> pg_backend_pid() AND l.locktype = 'relation'
          AND l.database = (SELECT oid FROM pg_database WHERE datname = current_database())
          AND (c.oid IS NULL OR (c.relname IN ('audit_log_events', 'settings_changes')))
        """,
        []
      )

    seen =
      Enum.reduce(rows, seen, fn [relation, mode], acc ->
        MapSet.put(acc, "#{relation}: #{mode}")
      end)

    receive do
      {:stop, from} ->
        GenServer.stop(conn)
        send(from, {:locks, Enum.sort(seen)})
    after
      10 -> poll_locks(conn, seen)
    end
  end

  defp start_reader(conn_config) do
    {:ok, conn} = Postgrex.start_link(conn_config)
    spawn_link(fn -> read_loop(conn, 0) end)
  end

  defp read_loop(conn, max_wait) do
    {micros, _result} =
      :timer.tc(fn ->
        Postgrex.query(
          conn,
          "SELECT id FROM audit_log_events ORDER BY inserted_at DESC LIMIT 25",
          []
        )
      end)

    max_wait = max(max_wait, micros)

    receive do
      {:stop, from} ->
        GenServer.stop(conn)
        send(from, {:max_wait, max_wait})
    after
      5 -> read_loop(conn, max_wait)
    end
  end

  # The size of audit_log_events right after the first conversion, before rollbacks leave dead
  # rows, next to the size settings_changes had.
  defp converted_size(repo) do
    sql(repo, "VACUUM ANALYZE audit_log_events")

    [[size]] =
      rows(repo, """
      SELECT pg_size_pretty(sum(pg_table_size(relid) + pg_indexes_size(relid)))
      FROM pg_partition_tree('audit_log_events')
      """)

    size
  end

  defp report(repo, rows, size, steps) do
    [[version]] = rows(repo, "SELECT current_setting('server_version')")

    for step <- steps do
      verdict =
        case step.seconds > @plan_b_seconds do
          true -> "ABOVE the #{@plan_b_seconds}s plan B threshold"
          false -> "below the #{@plan_b_seconds}s plan B threshold"
        end

      IO.puts(
        "#{step.label}: #{Float.round(step.seconds, 2)}s (#{verdict}), WAL #{step.wal_bytes} bytes, " <>
          "longest concurrent read wait #{step.max_read_wait_ms}ms, locks: #{Enum.join(step.locks, ", ")}"
      )
    end

    IO.puts(
      "Rehearsal passed with #{rows} bulk rows plus 3 boundary rows. audit_log_events after the " <>
        "first conversion: #{size} with indexes (settings_changes before it: " <>
        "#{Process.get(:history_size)}). PostgreSQL #{version}; WAL is cluster-wide, so run on " <>
        "an otherwise idle server."
    )
  end

  defp check(description, true), do: IO.puts("ok - #{description}")
  defp check(description, _), do: raise("Rehearsal check failed: #{description}")

  defp exists?(repo, name),
    do: rows(repo, "SELECT to_regclass($1) IS NOT NULL", [name]) == [[true]]

  defp sql(repo, statement, params \\ []), do: Ecto.Adapters.SQL.query!(repo, statement, params)
  defp rows(repo, statement, params \\ []), do: sql(repo, statement, params).rows
end

case Mix.env() do
  :test -> :ok
  _ -> raise("Migration rehearsal requires MIX_ENV=test")
end

{:ok, _} = Application.ensure_all_started(:ecto_sql)

rows = String.to_integer(System.get_env("SETTINGS_REHEARSAL_ROWS", "439180"))

config =
  Oli.Repo.config()
  |> Keyword.put(:database, "oli_settings_changes_conversion_rehearsal")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.put(:log, false)
  |> Keyword.put(:timeout, :infinity)
  |> Keyword.delete(:url)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  other -> raise("Refusing to reuse or delete rehearsal database: #{inspect(other)}")
end

try do
  {:ok, _pid} = Oli.Repo.start_link(config)

  Code.require_file(
    "priv/repo/migrations/20261119193918_convert_settings_changes_to_audit_events.exs"
  )

  conn_config = Keyword.drop(config, [:pool, :pool_size])
  SettingsChangesRehearsal.run(Oli.Repo, conn_config, rows)
after
  case Process.whereis(Oli.Repo) do
    nil -> :ok
    pid -> Supervisor.stop(pid)
  end

  :ok = Ecto.Adapters.Postgres.storage_down(config)
end

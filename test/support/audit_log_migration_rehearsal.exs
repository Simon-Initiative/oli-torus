# Rehearses the audit_log_events partitioning migration on a newly created disposable database:
# copy, reconciliation, grants, rollback, roll-forward, and the migration's refusals (reconciliation
# mismatch, non-object details, detached partition). Records durations, WAL bytes, sizes, locks,
# and how long a concurrent read waits. Never reuses or drops an existing database, and drops the
# temporary role it creates.
#
#   MIX_ENV=test mix run --no-start test/support/audit_log_migration_rehearsal.exs
#
# AUDIT_REHEARSAL_ROWS sets the synthetic legacy volume (default: production on 2026-10-29).
defmodule AuditLogMigrationRehearsalRepo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

defmodule AuditLogMigrationRehearsal do
  @version 20_261_030_155_349
  @migration Oli.Repo.Migrations.MigrateAuditLogEventsToPartitioned
  @plan_b_seconds 60
  @reader "oli_audit_rehearsal_reader"

  def reader, do: @reader

  def run(repo, conn_config, rows) do
    create_legacy_schema(repo)
    load_legacy_rows(repo, rows)
    original = legacy_snapshot(repo)

    first_up = measure(repo, conn_config, "up", fn -> migrate(repo, :up) end)
    verify_copy(repo, length(original))
    sizes = sizes(repo)
    ids = migrated_ids(repo)

    first_down = measure(repo, conn_config, "down", fn -> migrate(repo, :down) end)
    verify_rollback(repo, original)

    roll_forward = measure(repo, conn_config, "roll-forward", fn -> migrate(repo, :up) end)
    check("roll-forward keeps the migrated IDs", migrated_ids(repo) == ids)

    check(
      "roll-forward drops the archive",
      not exists?(repo, "audit_log_events_rollback_archive")
    )

    detached_partition_refusal(repo)

    v2_ids = insert_application_events(repo)
    migrate(repo, :down)
    verify_rollback_with_application_events(repo, v2_ids)

    old_binary_id = insert_old_binary_row(repo)
    forced_reconciliation_failure(repo)
    non_object_details_refusal(repo)

    final_up =
      measure(repo, conn_config, "roll-forward after new events", fn -> migrate(repo, :up) end)

    verify_roll_forward(repo, ids, v2_ids, old_binary_id)

    report(repo, rows, [first_up, first_down, roll_forward, final_up], sizes)
  end

  defp create_legacy_schema(repo) do
    sql(repo, """
    CREATE TABLE audit_log_events (
      id bigserial PRIMARY KEY,
      user_id integer,
      author_id integer,
      event_type varchar(255) NOT NULL,
      section_id integer,
      project_id integer,
      resource_id integer,
      details jsonb DEFAULT '{}'::jsonb,
      inserted_at timestamptz NOT NULL
    )
    """)

    for column <- ~w(user_id author_id section_id project_id event_type inserted_at) do
      sql(repo, "CREATE INDEX audit_log_events_#{column}_index ON audit_log_events (#{column})")
    end

    # A reporting role with read access, plus UPDATE that must not reach the append-only table.
    sql(repo, "GRANT SELECT, UPDATE ON audit_log_events TO #{@reader}")
    sql(repo, "GRANT SELECT ON SEQUENCE audit_log_events_id_seq TO #{@reader}")

    sql(repo, "CREATE TABLE settings_changes (id bigserial PRIMARY KEY, inserted_at timestamptz)")
    sql(repo, "INSERT INTO settings_changes (inserted_at) VALUES ('2024-07-29 10:00:00+00')")
  end

  # Bulk rows spread over the production date range with gaps between IDs, plus one row per
  # edge case of the copy projection. Bulk details carry about 400 bytes, near the production
  # average (3.7 MB for 6,269 rows including indexes).
  defp load_legacy_rows(repo, rows) do
    sql(repo, """
    INSERT INTO audit_log_events
      (id, user_id, author_id, event_type, section_id, project_id, details, inserted_at)
    SELECT g * 2 + 100,
           CASE WHEN g % 2 = 0 THEN g END,
           CASE WHEN g % 2 = 1 THEN g END,
           (ARRAY['project_published', 'section_created', 'google_doc_imported'])[g % 3 + 1],
           CASE WHEN g % 3 = 1 THEN g END,
           CASE WHEN g % 3 <> 1 THEN g END,
           jsonb_build_object('project_title', 'Project ' || g, 'version', '1.' || g,
                              'description', repeat('Course revision notes. ', 16)),
           timestamptz '2025-12-10 00:00:00+00'
             + (timestamptz '2026-10-29 00:00:00+00' - timestamptz '2025-12-10 00:00:00+00')
               * g / #{rows}
    FROM generate_series(1, #{rows}) g
    """)

    Process.put(:rehearsal_rows, rows)
    base = edge_id(0)

    edge_rows = [
      {base + 1, 11, nil, "user_deleted", nil, nil, 501,
       %{"email" => "deleted@example.edu", "resource_type" => "Elixir.Oli.Accounts.User"},
       "2026-03-01 10:00:00+00"},
      {base + 2, nil, 12, "author_role_changed", nil, nil, 502,
       %{
         "author_name" => "Ada Author",
         "author_email" => "ada@example.edu",
         "actor_name" => "Root Admin",
         "previous_role_id" => 1,
         "new_role_id" => 2,
         "resource_type" => "Elixir.Oli.Accounts.Author"
       }, "2026-03-02 10:00:00+00"},
      {base + 3, nil, nil, "feature_flag_enabled", nil, nil, nil, %{"feature_name" => "adaptive"},
       "2026-03-03 10:00:00+00"},
      {base + 4, 13, 14, "project_published", nil, 7, nil, %{"version" => "2.0"},
       "2026-03-04 10:00:00+00"},
      {base + 5, nil, 15, "google_doc_imported", nil, 8, nil,
       %{
         "api_token" => "SECRET-MARKER-1",
         "nested" => %{"Password" => "SECRET-MARKER-2", "page_title" => "Imported Doc"},
         "items" => [%{"session_cookie" => "SECRET-MARKER-3"}]
       }, "2026-03-05 10:00:00+00"},
      {base + 6, nil, 16, "clickhouse_admin_operation_initiated", nil, nil, nil,
       %{"operation_id" => "op-1", "kind" => "backfill"}, "2026-03-06 10:00:00+00"},
      {base + 7, nil, 17, "section_created", 31, nil, nil, %{"section_title" => "Before"},
       "2026-06-30 23:59:59.999999+00"},
      {base + 8, nil, 17, "section_created", 32, nil, nil, %{"section_title" => "After"},
       "2026-07-01 00:00:00+00"},
      {base + 9, 18, nil, "resource_attempt_deleted", nil, nil, 900,
       %{"resource_type" => "Elixir.Oli.Resources.Revision"}, "2026-03-07 10:00:00+00"},
      {base + 10, 19, nil, "user_deleted", nil, nil, nil, nil, "2026-03-08 10:00:00+00"}
    ]

    for {id, user_id, author_id, type, section_id, project_id, resource_id, details, at} <-
          edge_rows do
      sql(
        repo,
        """
        INSERT INTO audit_log_events
          (id, user_id, author_id, event_type, section_id, project_id, resource_id, details,
           inserted_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::text::timestamptz)
        """,
        [id, user_id, author_id, type, section_id, project_id, resource_id, details, at]
      )
    end

    # The sequence is ahead of the largest ID, as after deleted or failed inserts.
    sql(repo, "SELECT setval('audit_log_events_id_seq', $1)", [base + 50])
  end

  # Edge rows sit right above the bulk ID range.
  defp edge_id(offset), do: Process.get(:rehearsal_rows) * 2 + 1_000 + offset

  defp legacy_snapshot(repo) do
    rows(repo, """
    SELECT id, user_id, author_id, event_type, section_id, project_id, resource_id,
           COALESCE(details, '{}'), inserted_at
    FROM audit_log_events ORDER BY id
    """)
  end

  defp verify_copy(repo, legacy_count) do
    check("audit_log_events is partitioned", relkind(repo, "audit_log_events") == "p")
    check("the legacy sequence is gone", not exists?(repo, "audit_log_events_id_seq"))

    check(
      "every legacy row is copied once as v1",
      rows(repo, "SELECT count(*), count(DISTINCT legacy_id) FROM audit_log_events") ==
        [[legacy_count, legacy_count]]
    )

    check(
      "new IDs follow source order and start above the legacy sequence",
      rows(
        repo,
        """
        SELECT bool_and(id > previous_id) AND min(id) > $1
        FROM (SELECT id, lag(id, 1, 0::bigint) OVER (ORDER BY legacy_id) AS previous_id
              FROM audit_log_events) ordered
        """,
        [edge_id(50)]
      ) == [[true]]
    )

    check(
      "boundary rows route to their half-year",
      rows(
        repo,
        """
        SELECT tableoid::regclass::text FROM audit_log_events
        WHERE legacy_id IN ($1, $2) ORDER BY legacy_id
        """,
        [edge_id(7), edge_id(8)]
      ) ==
        [["audit_log_events_y2026h1"], ["audit_log_events_y2026h2"]]
    )

    check(
      "the oldest settings_changes row sets the first partition",
      exists?(repo, "audit_log_events_y2024h2")
    )

    expectations = [
      {1, ["user", "user", "501", 501, nil]},
      {2, ["author", "author", "502", nil, 502]},
      {3, ["unknown", nil, nil, nil, nil]},
      {4, ["unknown", "project", "7", nil, nil]},
      {9, ["user", nil, nil, nil, nil]}
    ]

    for {offset, expected} <- expectations do
      check(
        "actor and entity mapping for edge row #{offset}",
        rows(
          repo,
          """
          SELECT actor_type, entity_type, entity_id, affected_user_id, affected_author_id
          FROM audit_log_events WHERE legacy_id = $1
          """,
          [edge_id(offset)]
        ) == [expected]
      )
    end

    check(
      "non-account resource IDs move to legacy_resource_ref",
      rows(
        repo,
        "SELECT resource_id, details->'legacy_resource_ref' FROM audit_log_events WHERE legacy_id = $1",
        [edge_id(9)]
      ) == [[nil, %{"id" => 900, "type" => "Elixir.Oli.Resources.Revision"}]]
    )

    check(
      "secret values are replaced at any depth",
      rows(repo, "SELECT details FROM audit_log_events WHERE legacy_id = $1", [edge_id(5)]) ==
        [
          [
            %{
              "api_token" => %{"redacted" => true},
              "nested" => %{"Password" => %{"redacted" => true}, "page_title" => "Imported Doc"},
              "items" => [%{"session_cookie" => %{"redacted" => true}}]
            }
          ]
        ]
    )

    check(
      "no secret value is stored anywhere",
      rows(repo, """
      SELECT count(*) FROM audit_log_events
      WHERE details::text LIKE '%SECRET-MARKER%' OR search_text LIKE '%SECRET-MARKER%'
      """) == [[0]]
    )

    check(
      "search_text comes from identity values in details",
      rows(repo, "SELECT search_text FROM audit_log_events WHERE legacy_id = $1", [
        edge_id(2)
      ]) == [["Ada Author ada@example.edu Root Admin"]]
    )

    check(
      "only the ClickHouse event records an outcome",
      rows(repo, "SELECT event_type FROM audit_log_events WHERE outcome IS NOT NULL") ==
        [["clickhouse_admin_operation_initiated"]]
    )

    check(
      "grants are copied without mutation privileges",
      privileges(repo) == [true, false, true]
    )

    check(
      "migrated rows are append-only",
      match?(
        {:error, %Postgrex.Error{}},
        Ecto.Adapters.SQL.query(repo, "UPDATE audit_log_events SET details = '{}'", [])
      )
    )
  end

  defp verify_rollback(repo, original) do
    check("the original table is restored", relkind(repo, "audit_log_events") == "r")
    check("the partitioned sequence is gone", not exists?(repo, "audit_events_id_seq"))

    secret_id = edge_id(5)
    restored = legacy_snapshot(repo)

    check(
      "rollback restores every row under its legacy ID with its resource_id",
      Enum.map(restored, &List.delete_at(&1, 7)) == Enum.map(original, &List.delete_at(&1, 7))
    )

    check(
      "rollback restores the details of every other row unchanged",
      Enum.zip(original, restored)
      |> Enum.reject(fn {[id | _], _} -> id == secret_id end)
      |> Enum.all?(fn {left, right} -> Enum.at(left, 7) == Enum.at(right, 7) end)
    )

    check(
      "rollback keeps secrets sanitized",
      rows(repo, "SELECT details FROM audit_log_events WHERE id = $1", [secret_id]) ==
        [
          [
            %{
              "api_token" => %{"redacted" => true},
              "nested" => %{"Password" => %{"redacted" => true}, "page_title" => "Imported Doc"},
              "items" => [%{"session_cookie" => %{"redacted" => true}}]
            }
          ]
        ] and
        rows(
          repo,
          "SELECT count(*) FROM audit_log_events WHERE details::text LIKE '%SECRET-MARKER%'"
        ) ==
          [[0]]
    )

    check(
      "NULL details come back as the column default",
      rows(repo, "SELECT details FROM audit_log_events WHERE id = $1", [edge_id(10)]) == [[%{}]]
    )

    check(
      "rollback keeps the read grants",
      Enum.at(privileges(repo), 0) and Enum.at(privileges(repo), 2)
    )

    check(
      "the archive keeps the full history and the sequence is above it",
      rows(repo, """
      SELECT (SELECT count(*) FROM audit_log_events_rollback_archive) = (SELECT count(*) FROM audit_log_events),
             (SELECT last_value FROM audit_log_events_id_seq)
               >= (SELECT max(id) FROM audit_log_events_rollback_archive)
      """) == [[true, true]]
    )
  end

  defp migrated_ids(repo) do
    rows(repo, "SELECT legacy_id, id FROM audit_log_events WHERE schema_version = 1 ORDER BY 1")
  end

  # One event of a type the original table cannot hold and one of an original type.
  defp insert_application_events(repo) do
    [[new_type_id]] =
      rows(repo, """
      INSERT INTO audit_log_events
        (inserted_at, occurred_at, schema_version, event_type, outcome, actor_type, actor_key,
         entity_type, entity_id, source, operation_id, event_key)
      VALUES (now(), now(), 2, 'account_created', 'succeeded', 'system', 'provisioning',
              'user', '901', 'system', gen_random_uuid(), 'account:primary:created')
      RETURNING id
      """)

    [[legacy_type_id]] =
      rows(repo, """
      INSERT INTO audit_log_events
        (inserted_at, occurred_at, schema_version, event_type, outcome, actor_type, author_id,
         entity_type, entity_id, affected_user_id, details, source, operation_id, event_key)
      VALUES (now(), now(), 2, 'user_deleted', 'succeeded', 'author', 20, 'user', '777', 777,
              '{"email": "v2@example.edu"}', 'application', gen_random_uuid(),
              'account:primary:deleted')
      RETURNING id
      """)

    %{new_type: new_type_id, legacy_type: legacy_type_id}
  end

  defp verify_rollback_with_application_events(repo, %{new_type: new_type, legacy_type: legacy}) do
    check(
      "rollback rebuilds an original-type event in the legacy shape",
      rows(repo, "SELECT author_id, resource_id, details FROM audit_log_events WHERE id = $1", [
        legacy
      ]) ==
        [[20, 777, %{"email" => "v2@example.edu", "resource_type" => "Elixir.Oli.Accounts.User"}]]
    )

    check(
      "a new-type event stays only in the archive",
      rows(
        repo,
        """
        SELECT (SELECT count(*) FROM audit_log_events WHERE id = $1),
               (SELECT count(*) FROM audit_log_events_rollback_archive WHERE id = $1)
        """,
        [new_type]
      ) == [[0, 1]]
    )
  end

  # The old application writing after a rollback, through the legacy sequence.
  defp insert_old_binary_row(repo) do
    [[id]] =
      rows(repo, """
      INSERT INTO audit_log_events (author_id, event_type, project_id, details, inserted_at)
      VALUES (21, 'project_published', 9, '{"version": "3.0"}', now())
      RETURNING id
      """)

    check(
      "the old application writes above every archived ID",
      rows(repo, "SELECT max(id) FROM audit_log_events_rollback_archive") |> hd() |> hd() < id
    )

    id
  end

  # A partition detached for removal but not dropped must block the rollback with a clear error.
  defp detached_partition_refusal(repo) do
    sql(repo, "ALTER TABLE audit_log_events DETACH PARTITION audit_log_events_y2028h2")

    check(
      "a detached partition blocks the rollback by name",
      failure(fn -> migrate(repo, :down) end) =~ "audit_log_events_y2028h2"
    )

    sql(repo, """
    ALTER TABLE audit_log_events ATTACH PARTITION audit_log_events_y2028h2
      FOR VALUES FROM ('2028-07-01 00:00:00+00') TO ('2029-01-01 00:00:00+00')
    """)
  end

  # Details that are not a JSON object stop the migration with row IDs and no values.
  defp non_object_details_refusal(repo) do
    id = edge_id(4)
    [[details]] = rows(repo, "SELECT details FROM audit_log_events WHERE id = $1", [id])
    sql(repo, "UPDATE audit_log_events SET details = '\"SECRET-MARKER-4\"' WHERE id = $1", [id])
    error = failure(fn -> migrate(repo, :up) end)

    check(
      "non-object details stop the migration naming only the row",
      error =~ "ids: #{id}" and not (error =~ "SECRET-MARKER")
    )

    sql(repo, "UPDATE audit_log_events SET details = $1 WHERE id = $2", [details, id])
  end

  defp failure(fun) do
    try do
      fun.()
      ""
    rescue
      error -> Exception.message(error)
    end
  end

  # SELECT on the table, UPDATE on the table, SELECT on the sequence, for the reporting role.
  defp privileges(repo) do
    sequence =
      case relkind(repo, "audit_events_id_seq") do
        nil -> "audit_log_events_id_seq"
        _ -> "audit_events_id_seq"
      end

    [row] =
      rows(
        repo,
        """
        SELECT has_table_privilege($1, 'audit_log_events', 'SELECT'),
               has_table_privilege($1, 'audit_log_events', 'UPDATE'),
               has_sequence_privilege($1, $2, 'SELECT')
        """,
        [@reader, sequence]
      )

    row
  end

  # A legacy row deleted after rollback is still in the archive: roll-forward must refuse and
  # leave both tables as they were.
  defp forced_reconciliation_failure(repo) do
    deleted_id = edge_id(3)

    [deleted] =
      rows(repo, "SELECT * FROM audit_log_events WHERE id = $1", [deleted_id])

    sql(repo, "DELETE FROM audit_log_events WHERE id = $1", [deleted_id])
    [[legacy_count]] = rows(repo, "SELECT count(*) FROM audit_log_events")
    [[archive_count]] = rows(repo, "SELECT count(*) FROM audit_log_events_rollback_archive")

    check(
      "a reconciliation mismatch aborts the migration",
      failure(fn -> migrate(repo, :up) end) =~ "migrated_rows_without_legacy_row"
    )

    check(
      "the aborted migration leaves the legacy table and archive intact",
      relkind(repo, "audit_log_events") == "r" and not exists?(repo, "audit_log_events_p") and
        rows(repo, "SELECT count(*) FROM audit_log_events") == [[legacy_count]] and
        rows(repo, "SELECT count(*) FROM audit_log_events_rollback_archive") == [[archive_count]]
    )

    sql(repo, "INSERT INTO audit_log_events VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)", deleted)
  end

  defp verify_roll_forward(repo, ids, %{new_type: new_type, legacy_type: legacy}, old_binary_id) do
    check(
      "roll-forward restores application events once under their IDs",
      rows(
        repo,
        "SELECT id, schema_version FROM audit_log_events WHERE id IN ($1, $2) ORDER BY id",
        [new_type, legacy]
      ) == [[new_type, 2], [legacy, 2]]
    )

    [[_legacy_id, copied_id]] =
      rows(repo, "SELECT legacy_id, id FROM audit_log_events WHERE legacy_id = $1", [
        old_binary_id
      ])

    check(
      "roll-forward keeps earlier IDs and copies only the rows written after rollback",
      migrated_ids(repo) == ids ++ [[old_binary_id, copied_id]] and
        copied_id > Enum.max([new_type, legacy])
    )

    check(
      "roll-forward drops the archive",
      not exists?(repo, "audit_log_events_rollback_archive")
    )
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

  # Relations created by the uncommitted migration are not visible here; they are reported
  # together as "new relations".
  defp poll_locks(conn, seen) do
    %{rows: rows} =
      Postgrex.query!(
        conn,
        """
        SELECT DISTINCT COALESCE(c.relname, 'new relations'), l.mode
        FROM pg_locks l LEFT JOIN pg_class c ON c.oid = l.relation
        WHERE l.granted AND l.pid <> pg_backend_pid() AND l.locktype = 'relation'
          AND l.database = (SELECT oid FROM pg_database WHERE datname = current_database())
          AND (c.oid IS NULL OR (c.relname LIKE 'audit_log_events%' AND c.relkind IN ('r', 'p')))
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

  # Errors are expected while the table is swapped; only the wait matters.
  defp read_loop(conn, max_wait) do
    {micros, _result} =
      :timer.tc(fn -> Postgrex.query(conn, "SELECT 1 FROM audit_log_events LIMIT 1", []) end)

    max_wait = max(max_wait, micros)

    receive do
      {:stop, from} ->
        GenServer.stop(conn)
        send(from, {:max_wait, max_wait})
    after
      5 -> read_loop(conn, max_wait)
    end
  end

  defp sizes(repo) do
    [[table, indexes, partitions]] =
      rows(repo, """
      SELECT pg_size_pretty(sum(pg_table_size(relid))), pg_size_pretty(sum(pg_indexes_size(relid))),
             count(*) FILTER (WHERE isleaf)
      FROM pg_partition_tree('audit_log_events')
      """)

    %{table: table, indexes: indexes, partitions: partitions}
  end

  defp report(repo, rows, steps, sizes) do
    [[version, wal_level, details_bytes]] =
      rows(repo, """
      SELECT current_setting('server_version'), current_setting('wal_level'),
             (SELECT round(avg(pg_column_size(details))) FROM audit_log_events)
      """)

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
      "Rehearsal passed with #{rows} bulk rows plus 10 edge rows (average details " <>
        "#{details_bytes} bytes). Partitioned size: #{sizes.table} table, #{sizes.indexes} " <>
        "indexes, #{sizes.partitions} partitions. PostgreSQL #{version}, wal_level=#{wal_level}; " <>
        "WAL is cluster-wide, so run on an otherwise idle server."
    )
  end

  defp check(description, true), do: IO.puts("ok - #{description}")
  defp check(description, _), do: raise("Rehearsal check failed: #{description}")

  defp relkind(repo, name) do
    case rows(repo, "SELECT relkind::text FROM pg_class WHERE oid = to_regclass($1)", [name]) do
      [[kind]] -> kind
      [] -> nil
    end
  end

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

rows = String.to_integer(System.get_env("AUDIT_REHEARSAL_ROWS", "6269"))

config =
  Oli.Repo.config()
  |> Keyword.put(:database, "oli_audit_log_migration_rehearsal")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.put(:log, false)
  |> Keyword.delete(:url)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  other -> raise("Refusing to reuse or delete rehearsal database: #{inspect(other)}")
end

try do
  {:ok, _pid} = AuditLogMigrationRehearsalRepo.start_link(config)
  reader = AuditLogMigrationRehearsal.reader()

  # Roles are cluster-wide: refuse to reuse one, and drop it at the end.
  case Ecto.Adapters.SQL.query(
         AuditLogMigrationRehearsalRepo,
         "CREATE ROLE #{reader} NOLOGIN",
         []
       ) do
    {:ok, _} -> Process.put(:rehearsal_role, reader)
    {:error, error} -> raise("Refusing to reuse role #{reader}: #{Exception.message(error)}")
  end

  Code.require_file(
    "priv/repo/migrations/20261030155349_migrate_audit_log_events_to_partitioned.exs"
  )

  conn_config = Keyword.drop(config, [:pool, :pool_size])
  AuditLogMigrationRehearsal.run(AuditLogMigrationRehearsalRepo, conn_config, rows)
after
  case {Process.whereis(AuditLogMigrationRehearsalRepo), Process.get(:rehearsal_role)} do
    {nil, _role} ->
      :ok

    {pid, nil} ->
      Supervisor.stop(pid)

    {pid, role} ->
      Ecto.Adapters.SQL.query!(AuditLogMigrationRehearsalRepo, "DROP OWNED BY #{role}", [])
      Ecto.Adapters.SQL.query!(AuditLogMigrationRehearsalRepo, "DROP ROLE #{role}", [])
      Supervisor.stop(pid)
  end

  :ok = Ecto.Adapters.Postgres.storage_down(config)
end

# Benchmarks the partitioned audit_log_events layout on newly created disposable databases:
# six-month (the migration's layout) versus annual partitions, at growth-scenario volumes over
# five years. Measures insert latency, first-page queries with EXPLAIN (ANALYZE, BUFFERS) and the
# partitions each one scans, the admin list query, removal of the oldest partition with
# DETACH ... CONCURRENTLY, and partition provisioning with CREATE ... PARTITION OF versus the
# create-then-ATTACH sequence of `Oli.Auditing.Partitions`. One database exists at a time; each
# is dropped (forcing out leftover connections) before the next is created, and the run stops
# when the database volume has less free space than required. Reads are measured on a warm cache
# from a single client with custom plans.
#
#   MIX_ENV=test mix run --no-start test/support/audit_log_partition_benchmark.exs
#
# AUDIT_BENCHMARK_ROWS lists the volumes (default "1000000,10000000"). The production baseline
# on 2026-10-29 was about 600 central events per month, or about 200,000 rows per year if all
# assessment-setting history were central. Over five years, 1M rows is that rate and 10M is ten
# times it; 440,000 is about the size of the settings_changes history. These are scenarios, not
# measurements.
defmodule AuditLogPartitionBenchmarkRepo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

defmodule AuditLogPartitionBenchmark do
  alias Oli.Auditing.{BrowseOptions, Partitions}
  alias Oli.Repo.{Paging, Sorting}

  @repo AuditLogPartitionBenchmarkRepo
  @version 20_261_030_155_349
  @migration Oli.Repo.Migrations.MigrateAuditLogEventsToPartitioned
  @database "oli_audit_log_partition_benchmark"
  @min_free_gib 15
  @load_batch 1_000_000
  @runs 5

  @doc false
  def run(config, volumes) do
    # Helper processes are linked; a crash must reach the cleanup below instead of killing us.
    Process.flag(:trap_exit, true)

    results =
      for rows <- volumes, layout <- [:six_month, :annual] do
        with_database(config, rows, fn conn_config ->
          setup(layout, rows)
          result = measure(layout, rows)

          extra =
            case {layout, rows == hd(volumes)} do
              {:six_month, true} ->
                %{removal: removal(conn_config), provisioning: provisioning(conn_config)}

              _ ->
                %{}
            end

          Map.merge(result, extra)
        end)
      end

    report(results)
  end

  defp with_database(config, rows, fun) do
    refuse_without_space!(config, rows)
    config = Keyword.put(config, :database, @database)

    case Ecto.Adapters.Postgres.storage_up(config) do
      :ok -> :ok
      other -> raise("Refusing to reuse or delete benchmark database: #{inspect(other)}")
    end

    try do
      {:ok, _pid} = @repo.start_link(config)
      fun.(Keyword.drop(config, [:pool, :pool_size]))
    after
      case Process.whereis(@repo) do
        nil -> :ok
        pid -> Supervisor.stop(pid)
      end

      :ok = Ecto.Adapters.Postgres.storage_down(Keyword.put(config, :force_drop, true))
    end
  end

  # Volumes of a million rows or more need the free space; smaller runs only print it.
  defp refuse_without_space!(config, rows) do
    {:ok, conn} = Postgrex.start_link(Keyword.drop(config, [:pool, :pool_size]))
    %{rows: [[directory]]} = Postgrex.query!(conn, "SHOW data_directory", [])
    GenServer.stop(conn)

    output =
      case System.cmd("df", ["-Pk", directory], stderr_to_stdout: true) do
        {output, 0} -> output
        _ -> raise("Cannot check free space of #{directory}; the server must be local")
      end

    [_header, line | _] = String.split(output, "\n")
    free_gib = line |> String.split() |> Enum.at(3) |> String.to_integer() |> div(1024 * 1024)
    IO.puts("free space before #{rows} rows: #{free_gib} GiB")

    case rows >= 1_000_000 and free_gib < @min_free_gib do
      true ->
        raise(
          "Refusing to load #{rows} rows with #{free_gib} GiB free (#{@min_free_gib} GiB required)"
        )

      false ->
        :ok
    end
  end

  defp setup(layout, rows) do
    start = start_date()

    sql("""
    CREATE TABLE audit_log_events (
      id bigserial PRIMARY KEY, user_id integer, author_id integer,
      event_type varchar(255) NOT NULL, section_id integer, project_id integer,
      resource_id integer, details jsonb DEFAULT '{}'::jsonb, inserted_at timestamptz NOT NULL)
    """)

    # The oldest settings_changes row sets the first partition, five years back.
    sql("CREATE TABLE settings_changes (id bigserial PRIMARY KEY, inserted_at timestamptz)")
    sql("INSERT INTO settings_changes (inserted_at) VALUES ($1)", [start])
    :ok = Ecto.Migrator.up(@repo, @version, @migration, log: false)

    case layout do
      :six_month -> :ok
      :annual -> repartition_annually(start)
    end

    create_lookup_tables()
    load(rows, start)
    # Settles the visibility map and statistics so autovacuum does not run during measurements.
    sql("VACUUM (ANALYZE)")
  end

  defp start_date,
    do: DateTime.utc_now() |> DateTime.shift(year: -5) |> DateTime.truncate(:second)

  # Same parent, indexes, and checks; only the partition bounds differ. The per-partition
  # truncate trigger is left out because nothing here truncates.
  defp repartition_annually(start) do
    for name <- partition_names() do
      sql("ALTER TABLE audit_log_events DETACH PARTITION #{name}")
      sql("DROP TABLE #{name}")
    end

    for year <- start.year..(Date.utc_today().year + 2) do
      sql("""
      CREATE TABLE audit_log_events_y#{year} PARTITION OF audit_log_events
        FOR VALUES FROM ('#{year}-01-01 00:00:00+00') TO ('#{year + 1}-01-01 00:00:00+00')
      """)
    end
  end

  # The admin list joins these for names and slugs.
  defp create_lookup_tables do
    sql(
      "CREATE TABLE users AS SELECT g AS id, 'Student ' || g AS name, 'student' || g || '@example.edu' AS email FROM generate_series(1, 20000) g"
    )

    sql(
      "CREATE TABLE authors AS SELECT g AS id, 'Author ' || g AS name, 'author' || g || '@example.edu' AS email FROM generate_series(1, 2000) g"
    )

    sql(
      "CREATE TABLE projects AS SELECT g AS id, 'project-' || g AS slug, 'Project ' || g AS title FROM generate_series(1, 3000) g"
    )

    sql(
      "CREATE TABLE sections AS SELECT g AS id, 'section-' || g AS slug, 'Section ' || g AS title FROM generate_series(1, 10000) g"
    )

    for table <- ~w(users authors projects sections) do
      sql("ALTER TABLE #{table} ADD PRIMARY KEY (id)")
    end
  end

  # Version 2 rows in time order, shaped like the main families: student exceptions, manual
  # grades, section and project events, and system-provisioned accounts.
  defp load(rows, start) do
    for offset <- 0..(rows - 1)//@load_batch do
      count = min(@load_batch, rows - offset)

      sql(
        """
        INSERT INTO audit_log_events
          (inserted_at, occurred_at, schema_version, event_type, outcome, actor_type, actor_key,
           user_id, author_id, entity_type, entity_id, affected_user_id, project_id, section_id,
           resource_id, changes, source, operation_id, event_key, search_text)
        SELECT ts, ts, 2, kind.event_type, 'succeeded', kind.actor_type, kind.actor_key,
               kind.user_id, kind.author_id, kind.entity_type, kind.entity_id,
               kind.affected_user_id, kind.project_id, kind.section_id, kind.resource_id,
               kind.changes, kind.source, gen_random_uuid(), kind.event_key, kind.search_text
        FROM generate_series($1::bigint, $2::bigint) g
        CROSS JOIN LATERAL (
          SELECT $3::timestamptz + (now() - $3::timestamptz) * (g::double precision / $4::bigint) AS ts,
                 g % 10000 + 1 AS section, g % 5000 + 1 AS resource, (g * 7) % 20000 + 1 AS learner,
                 g % 20000 + 1 AS instructor, g % 2000 + 1 AS author, g % 3000 + 1 AS project
        ) v
        CROSS JOIN LATERAL (
          SELECT * FROM (VALUES
            (0, 'student_exception_updated', 'user', NULL, v.instructor, NULL, 'student_exception',
             'section:' || v.section || '/resource:' || v.resource || '/user:' || v.learner,
             v.learner, NULL, v.section, v.resource,
             '{"end_date": {"operation": "set", "before": null, "after": "2026-01-01T00:00:00Z"}}'::jsonb,
             'ui', 'section:' || v.section || ':exception', 'Student ' || v.learner || ' Section ' || v.section),
            (1, 'manual_grade_changed', 'user', NULL, v.instructor, NULL, 'resource_attempt',
             'attempt-' || g, v.learner, NULL, v.section, v.resource,
             '{"score": {"operation": "set", "before": 1, "after": 2}}'::jsonb,
             'ui', 'attempt:' || g || ':graded', 'Student ' || v.learner),
            (2, 'section_created', 'author', NULL, NULL, v.author, 'section', v.section::text,
             NULL, v.project, v.section, NULL, '{}'::jsonb,
             'ui', 'section:' || v.section || ':created', 'Section ' || v.section),
            (3, 'project_published', 'author', NULL, NULL, v.author, 'project', v.project::text,
             NULL, v.project, NULL, NULL, '{}'::jsonb,
             'ui', 'project:' || v.project || ':published', 'Project ' || v.project),
            (4, 'account_created', 'system', 'provisioning', NULL, NULL, 'user', v.learner::text,
             v.learner, NULL, NULL, NULL, '{}'::jsonb,
             'system', 'account:primary:created', 'Student ' || v.learner)
          ) AS k(idx, event_type, actor_type, actor_key, user_id, author_id, entity_type, entity_id,
                 affected_user_id, project_id, section_id, resource_id, changes, source,
                 event_key, search_text)
          WHERE k.idx = (ARRAY[0, 0, 0, 0, 1, 2, 2, 3, 3, 4])[g % 10 + 1]
        ) kind
        """,
        [offset + 1, offset + count, start, rows]
      )
    end
  end

  defp measure(layout, rows) do
    [[partitions, table, indexes]] =
      rows("""
      SELECT count(*) FILTER (WHERE isleaf), pg_size_pretty(sum(pg_table_size(relid))),
             pg_size_pretty(sum(pg_indexes_size(relid)))
      FROM pg_partition_tree('audit_log_events')
      """)

    %{
      layout: layout,
      rows: rows,
      partitions: partitions,
      table: table,
      indexes: indexes,
      single_insert: latency(200, fn -> insert_events(1) end),
      batch_insert: latency(20, fn -> insert_events(1_000) end),
      queries: Enum.map(queries(), fn {name, sql, params} -> {name, explain(sql, params)} end)
    }
  end

  defp insert_events(count) do
    sql(
      """
      INSERT INTO audit_log_events
        (inserted_at, occurred_at, schema_version, event_type, outcome, actor_type, author_id,
         entity_type, entity_id, project_id, source, operation_id, event_key, search_text)
      SELECT now(), now(), 2, 'project_published', 'succeeded', 'author', 1, 'project', '1', 1,
             'ui', gen_random_uuid(), 'project:1:published:' || g, 'Project 1'
      FROM generate_series(1, $1::integer) g
      """,
      [count]
    )
  end

  defp latency(times, fun) do
    samples =
      for _ <- 1..times do
        {micros, _} = :timer.tc(fun)
        micros / 1_000
      end

    %{median_ms: percentile(samples, 0.5), p95_ms: percentile(samples, 0.95)}
  end

  defp percentile(samples, p) do
    sorted = Enum.sort(samples)
    index = min(length(sorted) - 1, round(p * (length(sorted) - 1)))
    Float.round(Enum.at(sorted, index), 2)
  end

  defp queries do
    now = DateTime.utc_now()
    quarter_start = start_date() |> DateTime.shift(year: 2)

    admin = fn options ->
      Ecto.Adapters.SQL.to_sql(
        :all,
        @repo,
        Oli.Auditing.browse_events_query(
          %Paging{offset: 0, limit: 25},
          %Sorting{direction: :desc, field: :inserted_at},
          options
        )
      )
    end

    {admin_default, admin_default_params} = admin.(%BrowseOptions{})
    {admin_text, admin_text_params} = admin.(%BrowseOptions{text_search: "Student 4242"})
    {admin_type, admin_type_params} = admin.(%BrowseOptions{event_type: :project_published})

    [
      {"all history, first page",
       "SELECT * FROM audit_log_events ORDER BY inserted_at DESC, id DESC LIMIT 25", []},
      {"last 30 days, first page",
       "SELECT * FROM audit_log_events WHERE inserted_at >= $1 ORDER BY inserted_at DESC, id DESC LIMIT 25",
       [DateTime.shift(now, day: -30)]},
      {"one type in one quarter, first page",
       """
       SELECT * FROM audit_log_events
       WHERE event_type = 'project_published' AND inserted_at >= $1 AND inserted_at < $2
       ORDER BY inserted_at DESC, id DESC LIMIT 25
       """, [quarter_start, DateTime.shift(quarter_start, month: 3)]},
      {"one section, all history, first page",
       "SELECT * FROM audit_log_events WHERE section_id = 42 ORDER BY inserted_at DESC, id DESC LIMIT 25",
       []},
      {"one learner, all history, first page",
       "SELECT * FROM audit_log_events WHERE affected_user_id = 77 ORDER BY inserted_at DESC, id DESC LIMIT 25",
       []},
      {"admin list, default page", admin_default, admin_default_params},
      {"admin list, text search", admin_text, admin_text_params},
      {"admin list, one event type", admin_type, admin_type_params}
    ]
  end

  # Median of the timed runs after one warm-up, with their range; buffers and scanned partitions
  # from the median run. A partition counts as scanned only when its plan node ran; under LIMIT
  # most never run. Per-node timing is off so it does not inflate the heavy queries.
  defp explain(sql, params) do
    plans =
      for _ <- 0..@runs do
        [[[plan]]] = rows("EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, FORMAT JSON) " <> sql, params)
        plan
      end

    sorted = plans |> tl() |> Enum.sort_by(& &1["Execution Time"])
    median = Enum.at(sorted, div(@runs, 2))
    nodes = plan_nodes(median["Plan"])

    %{
      ms: Float.round(median["Execution Time"], 2),
      min_ms: Float.round(hd(sorted)["Execution Time"], 2),
      max_ms: Float.round(List.last(sorted)["Execution Time"], 2),
      planning_ms: Float.round(median["Planning Time"], 2),
      read_blocks: median["Plan"]["Shared Read Blocks"] || 0,
      hit_blocks: median["Plan"]["Shared Hit Blocks"] || 0,
      scanned:
        nodes
        |> Enum.filter(&((&1["Actual Loops"] || 0) > 0))
        |> Enum.map(& &1["Relation Name"])
        |> Enum.filter(&(is_binary(&1) and String.starts_with?(&1, "audit_log_events_y")))
        |> Enum.uniq()
        |> length(),
      removed: nodes |> Enum.map(&(&1["Subplans Removed"] || 0)) |> Enum.sum()
    }
  end

  defp plan_nodes(node), do: [node | Enum.flat_map(node["Plans"] || [], &plan_nodes/1)]

  # Detaches and drops the oldest partition while another connection keeps inserting.
  defp removal(conn_config) do
    [oldest | newer] = partition_names()
    before = Map.new(newer, &{&1, count(&1)})
    [[oldest_rows]] = rows("SELECT count(*) FROM #{oldest}")
    [[total_before]] = rows("SELECT count(*) FROM audit_log_events")

    writer = start_loop(conn_config, insert_sql(), [])

    {detach_us, _} =
      :timer.tc(fn ->
        sql("ALTER TABLE audit_log_events DETACH PARTITION #{oldest} CONCURRENTLY")
      end)

    {drop_us, _} = :timer.tc(fn -> sql("DROP TABLE #{oldest}") end)
    %{count: written, max_us: writer_max_us} = stop_loop(writer)

    current = Partitions.name_for(Date.utc_today())
    unchanged? = Enum.all?(newer -- [current], &(count(&1) == before[&1]))
    [[total_after]] = rows("SELECT count(*) FROM audit_log_events")

    check(
      "removing the oldest partition leaves newer partitions unchanged",
      not exists?(oldest) and unchanged? and total_after == total_before - oldest_rows + written
    )

    %{
      partition: oldest,
      rows: oldest_rows,
      detach_ms: div(detach_us, 1_000),
      drop_ms: div(drop_us, 1_000),
      concurrent_inserts: written,
      max_insert_ms: div(writer_max_us, 1_000)
    }
  end

  # A report-style read holds the parent for two seconds while a new partition is provisioned
  # and another connection keeps inserting. CREATE ... PARTITION OF needs ACCESS EXCLUSIVE on the
  # parent, so inserts queue behind it; ATTACH needs only SHARE UPDATE EXCLUSIVE. Both run like
  # `Partitions.ensure_through/1`: one transaction with a five-second lock timeout. The attach
  # path repeats the statements of `Partitions.create_partition/1`, which uses `Oli.Repo`.
  defp provisioning(conn_config) do
    create = fn ->
      in_transaction(fn ->
        sql("""
        CREATE TABLE audit_log_events_y2040h1 PARTITION OF audit_log_events
          FOR VALUES FROM ('2040-01-01 00:00:00+00') TO ('2040-07-01 00:00:00+00')
        """)

        truncate_trigger("audit_log_events_y2040h1")
      end)
    end

    attach = fn ->
      in_transaction(fn ->
        sql("""
        CREATE TABLE audit_log_events_y2040h2
          (LIKE audit_log_events INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED)
        """)

        sql("""
        ALTER TABLE audit_log_events ATTACH PARTITION audit_log_events_y2040h2
          FOR VALUES FROM ('2040-07-01 00:00:00+00') TO ('2041-01-01 00:00:00+00')
        """)

        truncate_trigger("audit_log_events_y2040h2")
      end)
    end

    %{
      create_partition_of: blocked_by_reader(conn_config, create),
      create_then_attach: blocked_by_reader(conn_config, attach)
    }
  end

  defp blocked_by_reader(conn_config, provision) do
    {:ok, reader} = Postgrex.start_link(conn_config)

    holder =
      Task.async(fn ->
        Postgrex.transaction(reader, fn conn ->
          Postgrex.query!(conn, "SELECT count(*) FROM audit_log_events WHERE section_id = 42", [])
          Postgrex.query!(conn, "SELECT pg_sleep(2)", [])
        end)
      end)

    Process.sleep(200)
    writer = start_loop(conn_config, insert_sql(), [])
    Process.sleep(100)
    {provision_us, _} = :timer.tc(provision)
    Task.await(holder, 10_000)
    %{max_us: max_us} = stop_loop(writer)
    GenServer.stop(reader)

    %{provision_ms: div(provision_us, 1_000), max_insert_ms: div(max_us, 1_000)}
  end

  defp in_transaction(fun) do
    {:ok, _} =
      @repo.transaction(fn ->
        sql("SET LOCAL lock_timeout = '5s'")
        fun.()
      end)
  end

  defp truncate_trigger(name) do
    sql("""
    CREATE TRIGGER audit_log_events_no_truncate BEFORE TRUNCATE ON #{name}
      FOR EACH STATEMENT EXECUTE FUNCTION audit_log_events_append_only()
    """)
  end

  defp insert_sql do
    """
    INSERT INTO audit_log_events
      (inserted_at, occurred_at, schema_version, event_type, outcome, actor_type, author_id,
       entity_type, entity_id, project_id, source, operation_id, event_key)
    VALUES (now(), now(), 2, 'project_published', 'succeeded', 'author', 1, 'project', '1', 1,
            'ui', gen_random_uuid(), 'project:1:published')
    """
  end

  defp start_loop(conn_config, statement, params) do
    {:ok, conn} = Postgrex.start_link(conn_config)
    spawn_link(fn -> loop(conn, statement, params, 0, 0) end)
  end

  defp loop(conn, statement, params, count, max_us) do
    {micros, _} = :timer.tc(fn -> Postgrex.query!(conn, statement, params) end)

    receive do
      {:stop, from} ->
        GenServer.stop(conn)
        send(from, {:stopped, %{count: count + 1, max_us: max(max_us, micros)}})
    after
      5 -> loop(conn, statement, params, count + 1, max(max_us, micros))
    end
  end

  defp stop_loop(pid) do
    send(pid, {:stop, self()})

    receive do
      {:stopped, result} -> result
      {:EXIT, ^pid, reason} -> raise("Benchmark helper failed: #{inspect(reason)}")
    end
  end

  defp report(results) do
    IO.puts(
      "\n| Layout | Rows | Partitions | Table | Indexes | Single insert median/p95 ms | 1,000-row insert median/p95 ms |"
    )

    IO.puts("| --- | --- | --- | --- | --- | --- | --- |")

    for r <- results do
      IO.puts(
        "| #{r.layout} | #{r.rows} | #{r.partitions} | #{r.table} | #{r.indexes} | " <>
          "#{r.single_insert.median_ms} / #{r.single_insert.p95_ms} | " <>
          "#{r.batch_insert.median_ms} / #{r.batch_insert.p95_ms} |"
      )
    end

    IO.puts(
      "\n| Query | Layout | Rows | Execution ms (min-max) | Planning ms | Shared hit / read blocks | Partitions scanned (executed) | Subplans removed |"
    )

    IO.puts("| --- | --- | --- | --- | --- | --- | --- | --- |")

    names = results |> hd() |> Map.fetch!(:queries) |> Enum.map(&elem(&1, 0))

    for name <- names, r <- results do
      q = r.queries |> List.keyfind(name, 0) |> elem(1)

      IO.puts(
        "| #{name} | #{r.layout} | #{r.rows} | #{q.ms} (#{q.min_ms}-#{q.max_ms}) | " <>
          "#{q.planning_ms} | #{q.hit_blocks} / #{q.read_blocks} | " <>
          "#{q.scanned} of #{r.partitions} | #{q.removed} |"
      )
    end

    for r <- results, Map.has_key?(r, :removal) do
      IO.puts("\nOldest-partition removal (#{r.rows} rows): #{inspect(r.removal)}")
      IO.puts("Partition provisioning behind a 2s read: #{inspect(r.provisioning)}")
    end
  end

  defp partition_names do
    rows("""
    SELECT c.relname FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
    WHERE i.inhparent = 'audit_log_events'::regclass ORDER BY c.relname
    """)
    |> List.flatten()
  end

  defp count(table), do: rows("SELECT count(*) FROM #{table}") |> hd() |> hd()
  defp exists?(name), do: rows("SELECT to_regclass($1) IS NOT NULL", [name]) == [[true]]

  defp check(description, true), do: IO.puts("ok - #{description}")
  defp check(description, _), do: raise("Benchmark check failed: #{description}")

  defp sql(statement, params \\ []),
    do: Ecto.Adapters.SQL.query!(@repo, statement, params, timeout: :infinity)

  defp rows(statement, params \\ []), do: sql(statement, params).rows
end

case Mix.env() do
  :test -> :ok
  _ -> raise("Partition benchmark requires MIX_ENV=test")
end

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)

Code.require_file(
  "priv/repo/migrations/20261030155349_migrate_audit_log_events_to_partitioned.exs"
)

volumes =
  "AUDIT_BENCHMARK_ROWS"
  |> System.get_env("1000000,10000000")
  |> String.split(",", trim: true)
  |> Enum.map(&String.to_integer/1)

config =
  Oli.Repo.config()
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.put(:log, false)
  |> Keyword.delete(:url)

AuditLogPartitionBenchmark.run(config, volumes)

defmodule Oli.Auditing.PartitionsTest do
  # Partition DDL locks the parent table, so these tests do not run alongside others.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog

  alias Oli.Auditing
  alias Oli.Auditing.{Error, EventExamples, LogEvent, Partitions}

  doctest Oli.Auditing.Partitions

  test "routes rows on each side of a half-year boundary to their partition" do
    for {inserted_at, partition} <- [
          {~U[2027-06-30 23:59:59.999999Z], "audit_log_events_y2027h1"},
          {~U[2027-07-01 00:00:00.000000Z], "audit_log_events_y2027h2"}
        ] do
      event = insert_example(inserted_at)

      %{rows: [[stored_in]]} =
        Repo.query!("SELECT tableoid::regclass::text FROM audit_log_events WHERE id = $1", [
          event.id
        ])

      assert stored_in == partition
      assert Auditing.get_event!(event.id, inserted_at).id == event.id
    end
  end

  test "ensure_through/1 creates only missing partitions" do
    far = Date.shift(Date.utc_today(), year: 3)

    assert {:ok, %{created: created, covered_through: covered_through}} =
             Partitions.ensure_through(far)

    assert Partitions.name_for(far) in created
    assert Date.compare(covered_through, far) != :lt

    assert {:ok, %{created: []}} = Partitions.ensure_through(far)
  end

  test "a partition created by ensure_through/1 matches the partitions the migration created" do
    far = Date.shift(Date.utc_today(), year: 3)
    {:ok, %{created: created}} = Partitions.ensure_through(far)
    name = Partitions.name_for(far)
    {from, to} = Partitions.bounds(far)

    assert name in created

    # The oldest partition always comes from the migration; ensure_through/1 only adds newer ones.
    [migrated | _] = partition_names()

    assert shape(name) == shape(migrated)

    # Bounds are printed in the session time zone and date style.
    Repo.query!("SET LOCAL TimeZone = 'UTC'")
    Repo.query!("SET LOCAL DateStyle = 'ISO'")

    %{rows: [[bound]]} =
      Repo.query!(
        "SELECT pg_get_expr(relpartbound, oid) FROM pg_class WHERE oid = $1::text::regclass",
        [name]
      )

    assert bound == "FOR VALUES FROM ('#{from} 00:00:00+00') TO ('#{to} 00:00:00+00')"
  end

  test "ensure_through/1 provisions partitions while another session reads the table" do
    {:ok, conn} = Postgrex.start_link(Keyword.drop(Repo.config(), [:pool, :pool_size]))
    test = self()

    reader =
      Task.async(fn ->
        Postgrex.transaction(conn, fn conn ->
          Postgrex.query!(conn, "SELECT 1 FROM audit_log_events LIMIT 1", [])
          send(test, :reading)

          receive do
            :release -> :ok
          end
        end)
      end)

    assert_receive :reading, 5_000

    try do
      # Creating with PARTITION OF would wait for the reader until the five-second lock timeout.
      {micros, result} =
        :timer.tc(fn -> Partitions.ensure_through(Date.shift(Date.utc_today(), year: 3)) end)

      assert {:ok, %{created: [_ | _]}} = result
      assert micros < 2_000_000
    after
      send(reader.pid, :release)
      Task.await(reader)
      GenServer.stop(conn)
    end
  end

  test "ensure_through/1 creates nothing while another session holds the lock" do
    {:ok, conn} = Postgrex.start_link(Keyword.drop(Repo.config(), [:pool, :pool_size]))

    Postgrex.query!(
      conn,
      "SELECT pg_advisory_lock(hashtext('oli.audit_log_events.partitions'))",
      []
    )

    try do
      assert {:ok, %{created: []}} =
               Partitions.ensure_through(Date.shift(Date.utc_today(), year: 3))
    after
      # Release explicitly: the server may still hold a session lock briefly after disconnect,
      # which would make the next test's ensure_through/1 skip its work.
      Postgrex.query!(
        conn,
        "SELECT pg_advisory_unlock(hashtext('oli.audit_log_events.partitions'))",
        []
      )

      GenServer.stop(conn)
    end
  end

  test "status/0 reports coverage and warns when few future partitions remain" do
    assert {:ok, %{future_intervals: future, current: current}} = Partitions.status()
    assert future >= 4
    assert current == Partitions.name_for(Date.utc_today())

    today = Date.utc_today()

    for months <- [18, 24] do
      assert :ok = Partitions.detach(Partitions.name_for(Date.shift(today, month: months)))
    end

    assert {:warning, %{future_intervals: 2}} = Partitions.status()
  end

  test "a missing partition returns a safe error, logs once, and emits telemetry" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:oli, :auditing, :append, :error]])

    changeset =
      LogEvent.v2_changeset(%LogEvent{}, %{
        EventExamples.example(:project_published)
        | inserted_at: ~U[1990-01-01 00:00:00.000000Z]
      })

    log =
      capture_log(fn ->
        assert {:error, %Error{code: :partition_missing, event_type: :project_published} = error} =
                 Auditing.insert(changeset)

        send(self(), {:error, error})
      end)

    assert_received {:error, %Error{correlation_id: correlation_id}}

    assert_received {[:oli, :auditing, :append, :error], ^ref, %{count: 1},
                     %{code: :partition_missing}}

    assert log =~ "correlation_id=#{correlation_id}"
    assert log =~ "partition=audit_log_events_y1990h1"
    refute log =~ "Intro Biology"
  end

  defp partition_names do
    %{rows: rows} =
      Repo.query!("""
      SELECT c.relname FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
      WHERE i.inhparent = 'audit_log_events'::regclass ORDER BY c.relname
      """)

    List.flatten(rows)
  end

  # Columns with types, nullability, generation, and defaults; constraints; index definitions
  # and triggers, with the partition's own name removed. Row triggers cloned from the parent are
  # marked internal on PostgreSQL 14, so they are matched by their parent trigger instead.
  defp shape(partition) do
    queries = [
      """
      SELECT a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull, a.attgenerated::text,
             pg_get_expr(d.adbin, d.adrelid)
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
      WHERE a.attrelid = $1::text::regclass AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY a.attnum
      """,
      """
      SELECT contype::text, CASE WHEN contype = 'p' THEN '' ELSE conname END,
             pg_get_constraintdef(oid)
      FROM pg_constraint WHERE conrelid = $1::text::regclass ORDER BY 1, 2, 3
      """,
      """
      SELECT regexp_replace(indexdef, '^(CREATE (UNIQUE )?INDEX) \\S+ ON \\S+ ', '\\1 ON partition ')
      FROM pg_indexes WHERE tablename = $1 ORDER BY 1
      """,
      """
      SELECT tgname FROM pg_trigger
      WHERE tgrelid = $1::text::regclass AND (NOT tgisinternal OR tgparentid <> 0)
      ORDER BY 1
      """
    ]

    Enum.map(queries, &Repo.query!(&1, [partition]).rows)
  end

  defp insert_example(inserted_at) do
    %LogEvent{}
    |> LogEvent.v2_changeset(%{
      EventExamples.example(:project_published)
      | inserted_at: inserted_at
    })
    |> Repo.insert!()
  end
end

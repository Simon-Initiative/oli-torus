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

  defp insert_example(inserted_at) do
    %LogEvent{}
    |> LogEvent.v2_changeset(%{
      EventExamples.example(:project_published)
      | inserted_at: inserted_at
    })
    |> Repo.insert!()
  end
end

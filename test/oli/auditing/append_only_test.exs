defmodule Oli.Auditing.AppendOnlyTest do
  # Creates and detaches a partition, which locks the parent table.
  use Oli.DataCase, async: false

  alias Oli.Auditing.{EventExamples, LogEvent, Partitions}

  setup do
    event =
      %LogEvent{}
      |> LogEvent.v2_changeset(EventExamples.example(:project_published))
      |> Repo.insert!()

    %{event: event}
  end

  test "updates and deletes raise", %{event: event} do
    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.transaction(fn ->
        Repo.update_all(from(e in LogEvent, where: e.id == ^event.id), set: [details: %{}])
      end)
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.transaction(fn -> Repo.delete_all(from(e in LogEvent, where: e.id == ^event.id)) end)
    end
  end

  test "truncating the table or one of its partitions raises" do
    partition = Partitions.name_for(Date.utc_today())

    for table <- ["audit_log_events", partition] do
      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        Repo.transaction(fn -> Repo.query!("TRUNCATE #{table}") end)
      end
    end
  end

  test "a partition created after the migration also blocks truncation" do
    far = Date.shift(Date.utc_today(), year: 3)
    assert {:ok, _report} = Partitions.ensure_through(far)

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.transaction(fn -> Repo.query!("TRUNCATE #{Partitions.name_for(far)}") end)
    end
  end

  test "a transaction that sets the documented override can change rows", %{event: event} do
    assert {:ok, {1, _}} =
             Repo.transaction(fn ->
               Repo.query!("SET LOCAL oli.audit_log_allow_mutation = 'on'")
               Repo.delete_all(from(e in LogEvent, where: e.id == ^event.id))
             end)
  end

  test "detaching a partition is not blocked" do
    Repo.query!("""
    CREATE TABLE audit_log_events_y2090h1 PARTITION OF audit_log_events
      FOR VALUES FROM ('2090-01-01 00:00:00+00') TO ('2090-07-01 00:00:00+00')
    """)

    assert :ok = Partitions.detach("audit_log_events_y2090h1")
    assert {:error, :not_found} = Partitions.detach("audit_log_events_y2090h1")
    assert {:error, :invalid_name} = Partitions.detach("audit_log_events; DROP TABLE users")
    assert {:error, :invalid_name} = Partitions.detach("audit_log_events_y2090h1\n")
  end
end

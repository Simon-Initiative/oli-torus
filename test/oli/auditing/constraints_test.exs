defmodule Oli.Auditing.ConstraintsTest do
  @moduledoc """
  The database checks on `audit_log_events`, exercised with inserts that bypass the
  application changeset, plus a round trip of every catalog example.
  """

  use Oli.DataCase

  import ExUnit.CaptureLog

  alias Oli.Auditing
  alias Oli.Auditing.{Error, EventCatalog, EventExamples, LogEvent}

  test "every writable example inserts and reads back unchanged" do
    for name <- EventCatalog.names(), name != :assessment_setting_changed do
      example = EventExamples.example(name)

      event =
        %LogEvent{}
        |> LogEvent.v2_changeset(example)
        |> Repo.insert!()

      stored = Repo.get_by!(LogEvent, id: event.id)

      for field <- [:event_type, :entity_type, :entity_id, :changes, :details, :refs, :outcome] do
        assert Map.fetch!(stored, field) == Map.fetch!(example, field),
               "#{name}: #{field} changed on the round trip"
      end

      assert stored.schema_version == 2
    end
  end

  describe "raw inserts" do
    setup do
      %{row: raw_row(:student_exception_updated)}
    end

    test "accept a valid version 2 row and a version 1 row with unknowns", %{row: row} do
      assert {1, _} = Repo.insert_all(LogEvent, [row])

      assert {1, _} =
               Repo.insert_all(LogEvent, [
                 %{
                   inserted_at: row.inserted_at,
                   schema_version: 1,
                   event_type: :project_published,
                   legacy_source: :audit_log_events,
                   legacy_id: 10
                 }
               ])
    end

    test "reject rows that break each check", %{row: row} do
      %{
        "audit_events_schema_version_check" => %{row | schema_version: 3},
        "audit_events_v1_provenance_check" => %{row | schema_version: 1},
        "audit_events_v2_envelope_check" => %{row | legacy_source: :audit_log_events},
        "audit_events_v2_actor_check" => %{row | author_id: 5},
        "audit_events_v2_learner_check" => %{row | affected_user_id: nil},
        "audit_events_v2_progress_restore_check" => %{
          raw_row(:learner_progress_restored)
          | section_id: nil
        },
        "audit_events_v1_only_names_check" => %{row | event_type: :assessment_setting_changed}
      }
      |> Enum.each(fn {constraint, invalid} ->
        assert_check_violation(constraint, fn -> Repo.insert_all(LogEvent, [invalid]) end)
      end)

      assert_check_violation("audit_events_v2_envelope_check", fn ->
        Repo.insert_all(LogEvent, [%{row | operation_id: nil}])
      end)

      assert_check_violation("audit_events_v2_actor_check", fn ->
        Repo.insert_all(LogEvent, [
          %{row | actor_type: :system, actor_key: "Bad Key", user_id: nil}
        ])
      end)
    end

    test "reject an event name or JSON shape the application could not produce" do
      assert_check_violation("audit_events_event_type_format_check", fn ->
        insert_sql("'Bad Name'", "'{}'")
      end)

      assert_check_violation("audit_events_json_shape_check", fn ->
        insert_sql("'project_published'", "'[]'")
      end)
    end

    test "reject a row outside every partition", %{row: row} do
      assert_raise Postgrex.Error, ~r/no partition of relation/, fn ->
        Repo.transaction(fn ->
          Repo.insert_all(LogEvent, [%{row | inserted_at: ~U[1990-01-01 00:00:00.000000Z]}])
        end)
      end
    end
  end

  describe "database rejections through the changeset" do
    test "the changeset declares every CHECK constraint on the table" do
      %{rows: rows} =
        Repo.query!("""
        SELECT conname FROM pg_constraint
        WHERE conrelid = 'audit_log_events'::regclass AND contype = 'c'
        """)

      assert Enum.sort(List.flatten(rows)) == Enum.sort(LogEvent.check_constraint_names())
    end

    test "a row only the database rejects returns a safe error, logs once, and emits telemetry" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:oli, :auditing, :append, :error]])

      changeset =
        %LogEvent{}
        |> LogEvent.v2_changeset(EventExamples.example(:project_published))
        |> Ecto.Changeset.force_change(:schema_version, 3)

      assert changeset.valid?

      log =
        capture_log(fn ->
          assert {:error, %Error{code: :invalid_event, event_type: :project_published} = error} =
                   Auditing.insert(changeset)

          send(self(), {:error, error})
        end)

      assert_received {:error, %Error{correlation_id: correlation_id}}

      assert_received {[:oli, :auditing, :append, :error], ^ref, %{count: 1},
                       %{code: :invalid_event}}

      assert log =~ "correlation_id=#{correlation_id}"
      refute log =~ "Intro Biology"
    end

    test "a database rejection inside a multi rolls back with an error" do
      multi =
        Ecto.Multi.new()
        |> Auditing.append(:audit, fn _changes ->
          changeset =
            %LogEvent{}
            |> LogEvent.v2_changeset(EventExamples.example(:project_published))
            |> Ecto.Changeset.force_change(:schema_version, 3)

          {:ok, changeset}
        end)

      capture_log(fn ->
        assert {:error, :audit, %Error{code: :invalid_event}, %{}} = Repo.transaction(multi)
      end)
    end

    test "an entity id is measured in code points, as the database measures it" do
      # 200 graphemes, each an "e" plus a combining accent: 400 code points.
      entity_id = String.duplicate("é", 200)
      assert String.length(entity_id) == 200

      changeset =
        LogEvent.v2_changeset(%LogEvent{}, %{
          EventExamples.example(:project_published)
          | entity_id: entity_id
        })

      assert {"must be 1 to 255 characters", _} = changeset.errors[:entity_id]

      at_limit = String.duplicate("é", 127) <> "e"

      assert %{valid?: true} =
               LogEvent.v2_changeset(%LogEvent{}, %{
                 EventExamples.example(:project_published)
                 | entity_id: at_limit
               })
    end
  end

  # Dumps an example through the schema types without running the changeset.
  defp raw_row(name) do
    name
    |> EventExamples.example()
    |> Map.drop([:id])
  end

  defp insert_sql(event_type, details) do
    Repo.query!("""
    INSERT INTO audit_log_events (inserted_at, schema_version, event_type, legacy_source,
      legacy_id, details)
    VALUES (now(), 1, #{event_type}, 'audit_log_events', 1, #{details}::jsonb)
    """)
  end

  defp assert_check_violation(constraint, fun) do
    error =
      assert_raise Postgrex.Error, fn ->
        Repo.transaction(fn -> fun.() end)
      end

    assert %{code: :check_violation, constraint: ^constraint} = error.postgres
  end
end

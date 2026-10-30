defmodule Oli.Auditing.ContractsTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.{Changes, EntityId, EventCatalog, EventExamples}
  alias Oli.Auditing.EventCatalog.Contract

  @writable for %Contract{v1_only: false, deprecated: false, name: name} <-
                  EventCatalog.contracts(),
                do: name

  test "every catalog event has an example" do
    assert EventCatalog.names() -- EventExamples.names() == []
  end

  describe "examples" do
    test "every writable example satisfies its contract" do
      for name <- @writable do
        assert EventCatalog.validate(EventExamples.example(name)) == :ok, "#{name}"
      end
    end

    test "the v1-only example is migrated history and is rejected as a new event" do
      example = EventExamples.example(:assessment_setting_changed)

      assert example.schema_version == 1
      assert example.legacy_source == "settings_changes"

      assert {:error, [event_type: "is not accepted for new events"]} =
               EventCatalog.validate(%{example | legacy_source: nil, legacy_id: nil})
    end

    test "account and authentication examples identify the affected account as the entity" do
      for %Contract{subject_is_affected: true, name: name} <- EventCatalog.contracts() do
        example = EventExamples.example(name)
        affected = example.affected_user_id || example.affected_author_id

        assert example.entity_id == Integer.to_string(affected), "#{name}"
      end
    end

    test "composite entity IDs round-trip through EntityId" do
      for name <- EventCatalog.names(),
          example = EventExamples.example(name),
          String.contains?(example.entity_id, "/") do
        {:ok, segments} = EntityId.parse(example.entity_id)

        assert EntityId.compose(Enum.map(segments, fn {t, id} -> {String.to_atom(t), id} end)) ==
                 example.entity_id
      end
    end
  end

  describe "derived invalid variants" do
    test "removing a required column is rejected" do
      for name <- @writable,
          column <- EventCatalog.contract!(name).required do
        assert_rejected(name, &Map.put(&1, column, nil), column)
      end
    end

    test "removing every alternative scope column is rejected" do
      for name <- @writable,
          columns = EventCatalog.contract!(name).required_one_of,
          columns != [] do
        assert_rejected(name, &Map.merge(&1, Map.new(columns, fn c -> {c, nil} end)), hd(columns))
      end
    end

    test "a missing affected person is rejected" do
      for name <- @writable,
          contract = EventCatalog.contract!(name),
          contract.affected_required do
        assert_rejected(
          name,
          &%{&1 | affected_user_id: nil, affected_author_id: nil},
          :"affected_#{hd(contract.affected_kinds)}_id"
        )
      end
    end

    test "an affected person the contract does not allow is rejected" do
      for name <- @writable, EventCatalog.contract!(name).affected_kinds == [] do
        assert_rejected(name, &%{&1 | affected_user_id: 999}, :affected_user_id)
      end
    end

    test "an affected author on a user-only contract is rejected" do
      for name <- @writable, EventCatalog.contract!(name).affected_kinds == [:user] do
        assert_rejected(name, &%{&1 | affected_author_id: 999}, :affected_author_id)
      end
    end

    test "a wrong entity type is rejected" do
      for name <- @writable do
        assert_rejected(name, &%{&1 | entity_type: :not_an_entity}, :entity_type)
      end
    end

    test "a disallowed actor kind is rejected" do
      for name <- @writable, :system not in EventCatalog.contract!(name).actor_kinds do
        assert_rejected(
          name,
          &%{
            &1
            | actor_type: :system,
              actor_key: "scheduled_maintenance",
              user_id: nil,
              author_id: nil
          },
          :actor_type
        )
      end
    end

    test "an actor with both account IDs is rejected" do
      for name <- @writable do
        assert_rejected(name, &%{&1 | user_id: 1, author_id: 2}, :actor_type)
      end
    end

    test "a disallowed outcome is rejected" do
      for name <- @writable do
        outcome =
          Enum.find(~w(initiated canceled)a, &(&1 not in EventCatalog.contract!(name).outcomes))

        assert outcome, "#{name} allows every probe outcome"
        assert_rejected(name, &%{&1 | outcome: outcome}, :outcome)
      end
    end

    test "an unknown change field is rejected" do
      for name <- @writable do
        assert_rejected(
          name,
          &%{&1 | changes: %{"not_a_field" => %{"operation" => "set", "after" => 1}}},
          :changes
        )
      end
    end

    test "an unknown detail key is rejected" do
      for name <- @writable do
        assert_rejected(name, &%{&1 | details: %{"not_a_key" => 1}}, :details)
      end
    end

    test "empty changes on a skip contract are a no-op" do
      for name <- @writable, EventCatalog.contract!(name).no_op == :skip do
        assert EventCatalog.validate(%{EventExamples.example(name) | changes: %{}}) ==
                 {:error, :no_changes},
               "#{name}"
      end
    end

    test "legacy provenance on a new event is rejected" do
      for name <- @writable do
        assert_rejected(
          name,
          &%{&1 | legacy_source: "audit_log_events", legacy_id: 1},
          :legacy_source
        )
      end
    end
  end

  describe "envelope" do
    setup do
      %{example: EventExamples.example(:student_exception_updated)}
    end

    test "requires occurred_at, a UUID operation, a valid key, and a known source", %{
      example: example
    } do
      assert {:error, errors} =
               EventCatalog.validate(%{
                 example
                 | occurred_at: nil,
                   operation_id: "not-a-uuid",
                   event_key: "Not A Key",
                   source: :email
               })

      columns = Keyword.keys(errors)
      assert :occurred_at in columns
      assert :operation_id in columns
      assert :event_key in columns
      assert :source in columns
    end

    test "rejects an unknown system actor key" do
      example = EventExamples.example(:account_created)
      assert {:error, errors} = EventCatalog.validate(%{example | actor_key: "root"})
      assert {:actor_type, _} = List.keyfind(errors, :actor_type, 0)
    end

    test "rejects unknown event names" do
      assert {:error, [event_type: "is not a catalog event"]} =
               EventCatalog.validate(%{event_type: :made_up_event})

      assert {:error, [event_type: "is not a catalog event"]} =
               EventCatalog.validate(%{event_type: "made_up_event"})
    end

    test "rejects a secret value outside a secret field without echoing it", %{example: example} do
      marker = "marker-#{System.unique_integer([:positive])}"

      changes =
        Map.put(example.changes, "max_attempts", %{
          "operation" => "set",
          "after" => %{"api_token" => marker}
        })

      assert {:error, errors} = EventCatalog.validate(%{example | changes: changes})
      refute inspect(errors) =~ marker

      assert {:error, errors} =
               EventCatalog.validate(%{
                 example
                 | changes: %{"password" => %{"operation" => "set", "after" => marker}}
               })

      refute inspect(errors) =~ marker
    end

    test "rejects secret-looking detail keys and oversized details" do
      example = EventExamples.example(:google_doc_imported)

      assert {:error, errors} =
               EventCatalog.validate(%{
                 example
                 | details: Map.put(example.details, "warning_codes", %{"oauth_token" => 1})
               })

      assert {:details, _} = List.keyfind(errors, :details, 0)

      big = String.duplicate("a", 17_000)

      assert {:error, errors} =
               EventCatalog.validate(%{example | details: %{"page_title" => big}})

      assert [details: "exceed 16384 bytes"] = errors
    end

    test "returns errors instead of raising on malformed input" do
      account = EventExamples.example(:account_updated)

      assert {:error, errors} = EventCatalog.validate(%{account | affected_user_id: "77"})
      assert List.keymember?(errors, :affected_user_id, 0)

      import_example = EventExamples.example(:google_doc_imported)

      assert {:error, errors} =
               EventCatalog.validate(%{import_example | details: %{"page_title" => <<0xFF>>}})

      assert List.keymember?(errors, :details, 0)

      assert {:error, errors} =
               EventCatalog.validate(%{import_example | details: %{{:bad} => 1}})

      assert List.keymember?(errors, :details, 0)

      malformed = [
        actor_snapshot: ~D[2026-01-01],
        actor_snapshot: %{{1, 2} => "x"},
        entity_snapshot: %{"name" => <<0xFF, 0xFE>>},
        changes: ~D[2026-01-01],
        details: ~D[2026-01-01],
        details: %{"page_title" => ["a" | "b"]},
        entity_id: <<0xFF, 0xFE>>
      ]

      for {column, value} <- malformed do
        assert {:error, errors} = EventCatalog.validate(Map.put(import_example, column, value))
        assert List.keymember?(errors, column, 0)
      end

      for entity_type <- [%{}, [:user]] do
        assert {:error, errors} = EventCatalog.validate(%{account | entity_type: entity_type})
        assert List.keymember?(errors, :entity_id, 0)
      end
    end

    test "rejects non-positive account IDs and snapshot fields of another actor kind" do
      example = EventExamples.example(:google_doc_imported)

      assert {:error, errors} = EventCatalog.validate(%{example | author_id: 0})
      assert List.keymember?(errors, :actor_type, 0)

      assert {:error, errors} =
               EventCatalog.validate(%{example | actor_snapshot: %{"key" => "x", "label" => "y"}})

      assert List.keymember?(errors, :actor_snapshot, 0)
    end

    test "rejects snapshot values and reference labels over 255 characters" do
      example = EventExamples.example(:project_published)
      long = String.duplicate("a", 256)

      assert {:error, errors} =
               EventCatalog.validate(%{example | entity_snapshot: %{"title" => long}})

      assert List.keymember?(errors, :entity_snapshot, 0)

      assert {:error, [refs: _]} =
               EventCatalog.validate(%{
                 example
                 | refs: [
                     %{"role" => "resulting", "type" => "project", "id" => 1, "label" => long}
                   ]
               })
    end

    test "reports legacy provenance and author-only affected errors on their own columns" do
      example = EventExamples.example(:project_ownership_changed)

      assert {:error, errors} = EventCatalog.validate(%{example | legacy_id: 1})
      assert List.keymember?(errors, :legacy_id, 0)
      refute List.keymember?(errors, :legacy_source, 0)

      assert {:error, errors} = EventCatalog.validate(%{example | affected_author_id: nil})
      assert List.keymember?(errors, :affected_author_id, 0)
    end

    test "rejects invalid references" do
      example = EventExamples.example(:project_published)

      assert {:error, [refs: _]} =
               EventCatalog.validate(%{
                 example
                 | refs: [%{"role" => "linked", "type" => "project", "id" => 1}]
               })

      assert {:error, [refs: _]} =
               EventCatalog.validate(%{
                 example
                 | refs: [%{"role" => "resulting", "type" => "Bad Type", "id" => 1}]
               })

      assert {:error, [refs: _]} =
               EventCatalog.validate(%{
                 example
                 | refs: [%{"role" => "resulting", "type" => "project", "id" => -1}]
               })
    end

    test "multi-field changes, resets with effective values, and secret markers are accepted" do
      assert :ok = EventCatalog.validate(EventExamples.example(:assessment_settings_reset))

      example = EventExamples.example(:student_exception_updated)
      assert example.changes["password"] == Changes.secret_record()
      assert map_size(example.changes) == 2
    end

    test "events of one bulk command share the operation and differ by key" do
      base = EventExamples.example(:student_exception_updated)

      rows =
        for user_id <- [77, 78, 79] do
          %{
            base
            | affected_user_id: user_id,
              entity_id: EntityId.compose(section: 301, resource: 4512, user: user_id),
              event_key: "exception:#{user_id}:updated"
          }
        end

      assert Enum.all?(rows, &(EventCatalog.validate(&1) == :ok))
      assert rows |> Enum.map(& &1.operation_id) |> Enum.uniq() |> length() == 1
      assert rows |> Enum.map(& &1.event_key) |> Enum.uniq() |> length() == 3
    end

    test "an async operation records initiation and a terminal outcome with one operation" do
      initiated = EventExamples.example(:clickhouse_admin_operation_initiated)
      terminal = EventExamples.example(:clickhouse_admin_operation_outcome)

      assert :ok = EventCatalog.validate(initiated)
      assert :ok = EventCatalog.validate(terminal)
      assert initiated.operation_id == terminal.operation_id
      assert initiated.outcome == :initiated
      assert terminal.outcome in [:succeeded, :failed, :canceled, :partial, :unknown]
    end
  end

  defp assert_rejected(name, mutate, column) do
    result = name |> EventExamples.example() |> mutate.() |> EventCatalog.validate()

    assert {:error, errors} = result, "#{name}: expected rejection on #{column}"
    assert is_list(errors), "#{name}: expected field errors, got #{inspect(errors)}"
    assert List.keymember?(errors, column, 0), "#{name}: #{inspect(errors)} lacks #{column}"
  end
end

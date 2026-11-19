defmodule Oli.Auditing.LegacyAdapterTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing
  alias Oli.Auditing.{Error, EventCatalog, LegacyAdapter}

  setup do
    %{admin: insert(:author), user: insert(:user)}
  end

  test "covers the remaining legacy event types, all in the catalog" do
    events = LegacyAdapter.events()

    assert Enum.sort(events) ==
             Enum.sort(~w(clickhouse_admin_operation_initiated resource_attempt_deleted)a)

    assert events -- EventCatalog.names() == []
  end

  test "events whose producers moved to audited facades are rejected", %{admin: admin} do
    for event <- ~w(user_deleted author_deleted author_role_changed account_internal_flag_changed
                    feature_flag_enabled feature_rollout_stage_changed project_published
                    google_doc_imported section_created)a do
      assert {:error, %Error{code: :invalid_event}} = Auditing.capture(admin, event, admin, %{})
    end
  end

  test "attempt deletion records the student as the affected person", %{user: instructor} do
    section = insert(:section)
    student = insert(:user)

    assert {:ok, event} =
             Auditing.capture(instructor, :resource_attempt_deleted, section, %{
               "attempt_guid" => "3F9C-guid",
               "user_id" => student.id,
               "section_id" => section.id,
               "resource_id" => 4512
             })

    assert {event.entity_type, event.entity_id} == {:resource_attempt, "3F9C-guid"}
    assert {event.section_id, event.resource_id} == {section.id, 4512}
    assert event.affected_user_id == student.id
    assert event.event_key == "attempt:3f9c-guid:deleted"
  end

  test "ClickHouse operations are recorded as initiated", %{admin: admin} do
    assert {:ok, event} =
             Auditing.log_admin_action(admin, :clickhouse_admin_operation_initiated, nil, %{
               "operation_id" => 512,
               "kind" => "migrate_up",
               "operation_label" => "Run ClickHouse migrations"
             })

    assert {event.outcome, event.entity_type, event.entity_id} ==
             {:initiated, :clickhouse_operation, "512"}

    assert event.entity_snapshot == %{"label" => "Run ClickHouse migrations"}
  end

  test "every legacy event is written as an application event with a new operation", %{
    admin: admin
  } do
    section = insert(:section)
    details = attempt_details(section, insert(:user))
    assert {:ok, first} = Auditing.capture(admin, :resource_attempt_deleted, section, details)
    assert {:ok, second} = Auditing.capture(admin, :resource_attempt_deleted, section, details)

    assert first.source == :application
    assert first.schema_version == 2
    assert first.operation_id != second.operation_id
  end

  test "rejects a nil actor and shapes it cannot map", %{admin: admin} do
    section = insert(:section)

    assert {:error, %Error{code: :invalid_event}} =
             Auditing.capture(
               nil,
               :resource_attempt_deleted,
               section,
               attempt_details(section, insert(:user))
             )

    assert {:error, %Error{code: :invalid_event}} =
             Auditing.capture(admin, :resource_attempt_deleted, section, %{})
  end

  defp attempt_details(section, student) do
    %{
      "attempt_guid" => "attempt-#{System.unique_integer([:positive])}",
      "user_id" => student.id,
      "section_id" => section.id,
      "resource_id" => 4512
    }
  end
end

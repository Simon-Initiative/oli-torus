defmodule Oli.Auditing.LegacyAdapterTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Auditing
  alias Oli.Auditing.{Error, EventCatalog, LegacyAdapter}

  setup do
    %{admin: insert(:author), user: insert(:user), project: insert(:project)}
  end

  test "covers the 16 legacy event types, all in the catalog" do
    events = LegacyAdapter.events()

    assert length(events) == 16
    assert events -- EventCatalog.names() == []
  end

  test "account deletions record the deleted account as entity and affected person", %{
    admin: admin
  } do
    deleted_user = insert(:user)
    deleted_author = insert(:author)

    assert {:ok, user_event} =
             Auditing.log_admin_action(admin, :user_deleted, deleted_user, %{
               "email" => deleted_user.email,
               "deleted_by" => admin.email
             })

    assert {user_event.entity_type, user_event.affected_user_id, user_event.event_key} ==
             {:user, deleted_user.id, "account:primary:deleted"}

    assert user_event.details == %{"email" => deleted_user.email, "deleted_by" => admin.email}

    assert {:ok, author_event} =
             Auditing.log_admin_action(admin, :author_deleted, deleted_author, %{})

    assert {author_event.entity_type, author_event.affected_author_id} ==
             {:author, deleted_author.id}
  end

  test "role and internal flag changes record before and after values", %{admin: admin} do
    author = insert(:author)
    user = insert(:user)

    assert {:ok, role_event} =
             Auditing.log_admin_action(admin, :author_role_changed, author, %{
               "previous_role_id" => 1,
               "new_role_id" => 2,
               "previous_role" => "author",
               "new_role" => "admin"
             })

    assert role_event.affected_author_id == author.id

    assert role_event.changes == %{
             "system_role_id" => %{"operation" => "set", "before" => 1, "after" => 2}
           }

    assert {:ok, flag_event} =
             Auditing.capture(admin, :account_internal_flag_changed, user, %{
               "account_type" => "user",
               "previous" => false,
               "is_internal" => true
             })

    assert flag_event.affected_user_id == user.id

    assert flag_event.changes["is_internal"] == %{
             "operation" => "set",
             "before" => false,
             "after" => true
           }
  end

  test "project events record the project and the imported page", %{
    admin: admin,
    project: project
  } do
    assert {:ok, published} =
             Auditing.capture(admin, :project_published, project, %{
               "publication_id" => 12,
               "version" => "1.2.0"
             })

    assert {published.project_id, published.entity_type, published.event_key} ==
             {project.id, :project, "project:#{project.id}:published"}

    assert published.refs == [
             %{"role" => "resulting", "type" => "publication", "id" => 12, "label" => "1.2.0"}
           ]

    assert {:ok, imported} =
             Auditing.capture(admin, :google_doc_imported, project, %{"page_resource_id" => 45})

    assert {imported.project_id, imported.resource_id} == {project.id, 45}
  end

  test "section creation records the section and its base project", %{user: user} do
    section = insert(:section)

    assert {:ok, event} =
             Auditing.capture(user, :section_created, section, %{
               "base_project_id" => section.base_project_id
             })

    assert {event.section_id, event.project_id, event.entity_type} ==
             {section.id, section.base_project_id, :section}
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

  test "feature flags use the project or section column, or a global scope reference", %{
    admin: admin,
    project: project
  } do
    section = insert(:section)

    assert {:ok, enabled} =
             Auditing.capture(admin, :feature_flag_enabled, project, %{
               "feature_name" => :mcp_authoring,
               "enabled" => true
             })

    assert {enabled.entity_type, enabled.entity_id, enabled.project_id} ==
             {:feature_flag, "mcp_authoring", project.id}

    assert {:ok, disabled} =
             Auditing.capture(admin, :feature_flag_disabled, section, %{"feature_name" => "x"})

    assert disabled.section_id == section.id

    assert {:ok, removed} =
             Auditing.capture(admin, :feature_flag_removed, nil, %{"feature_name" => "x"})

    assert [%{"role" => "scope", "type" => "global"}] = removed.refs
  end

  test "rollouts and exemptions record their scope", %{admin: admin} do
    assert {:ok, stage} =
             Auditing.capture(admin, :feature_rollout_stage_changed, nil, %{
               "feature_name" => "adaptive_dot",
               "scope_type" => "project",
               "scope_id" => 88,
               "stage" => "full"
             })

    assert {stage.entity_type, stage.project_id, stage.event_key} ==
             {:feature_rollout, 88, "rollout:adaptive_dot:project_88:stage_changed"}

    assert {:ok, deleted} =
             Auditing.capture(admin, :feature_rollout_stage_deleted, nil, %{
               "feature_name" => "adaptive_dot",
               "scope_type" => "global"
             })

    assert [%{"type" => "global"}] = deleted.refs

    for event <- [:feature_rollout_exemption_upserted, :feature_rollout_exemption_deleted] do
      assert {:ok, exemption} =
               Auditing.capture(admin, event, nil, %{
                 "feature_name" => "adaptive_dot",
                 "publisher_id" => 3,
                 "effect" => "deny"
               })

      assert {exemption.entity_type, exemption.entity_id} ==
               {:rollout_exemption, "adaptive_dot:publisher:3"}

      assert [%{"role" => "scope", "type" => "publisher", "id" => 3}] = exemption.refs
    end
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
    admin: admin,
    project: project
  } do
    assert {:ok, first} = Auditing.capture(admin, :project_published, project, %{})
    assert {:ok, second} = Auditing.capture(admin, :project_published, project, %{})

    assert first.source == :application
    assert first.schema_version == 2
    assert first.operation_id != second.operation_id
  end

  test "rejects a nil actor and shapes it cannot map", %{project: project, admin: admin} do
    assert {:error, %Error{code: :invalid_event}} =
             Auditing.capture(nil, :project_published, project, %{})

    assert {:error, %Error{code: :invalid_event}} =
             Auditing.capture(admin, :project_published, nil, %{})
  end
end

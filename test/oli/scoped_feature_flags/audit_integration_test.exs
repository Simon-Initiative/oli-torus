defmodule Oli.ScopedFeatureFlags.AuditIntegrationTest do
  use Oli.DataCase

  alias Oli.Auditing
  alias Oli.Auditing.LogEvent
  alias Oli.ScopedFeatureFlags

  import Oli.Factory

  describe "enable_feature audit logging" do
    test "logs feature flag enabled event for project with author" do
      author = insert(:author)
      project = insert(:project)

      assert {:ok, _flag_state} =
               Oli.ScopedFeatureFlags.Audited.enable_feature(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 :mcp_authoring,
                 project
               )

      # Check that an audit log entry was created
      events = Auditing.list_events()
      assert length(events) == 1

      event = List.first(events)
      assert event.event_type == :feature_flag_enabled
      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.details["feature_name"] == "mcp_authoring"
      assert event.details["enabled"] == true
      assert event.details["resource_type"] == "project"
    end

    test "validates scope constraints when enabling features" do
      user = insert(:user)
      section = insert(:section)

      # mcp_authoring should fail on section since it's authoring-scoped only
      assert {:error, %{invalid_scope: [error_msg]}} =
               Oli.ScopedFeatureFlags.Audited.enable_feature(
                 Oli.Auditing.Context.for_actor(user, source: :ui),
                 :mcp_authoring,
                 section
               )

      assert error_msg =~ "does not support scope 'delivery'"

      # Check that no audit log entry was created for invalid operation
      events = Auditing.list_events()
      assert length(events) == 0
    end
  end

  describe "disable_feature audit logging" do
    test "logs feature flag disabled event for project with author" do
      author = insert(:author)
      project = insert(:project)

      # First enable the feature
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          :mcp_authoring,
          project
        )

      assert {:ok, _flag_state} =
               Oli.ScopedFeatureFlags.Audited.disable_feature(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 :mcp_authoring,
                 project
               )

      # Check that an audit log entry was created; enabling the feature recorded its own event.
      assert [event] = Auditing.list_events(event_type: :feature_flag_disabled)
      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.details["feature_name"] == "mcp_authoring"
      assert event.details["enabled"] == false
      assert event.details["resource_type"] == "project"
    end

    test "validates scope constraints when disabling features" do
      user = insert(:user)
      section = insert(:section)

      # mcp_authoring should fail on section since it's authoring-scoped only
      assert {:error, %{invalid_scope: [error_msg]}} =
               Oli.ScopedFeatureFlags.Audited.disable_feature(
                 Oli.Auditing.Context.for_actor(user, source: :ui),
                 :mcp_authoring,
                 section
               )

      assert error_msg =~ "does not support scope 'delivery'"

      # Check that no audit log entry was created for invalid operation
      events = Auditing.list_events()
      assert length(events) == 0
    end
  end

  describe "remove_feature audit logging" do
    test "logs feature flag removed event for project with author" do
      author = insert(:author)
      project = insert(:project)

      # First enable the feature
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          :mcp_authoring,
          project
        )

      assert {:ok, _deleted_state} =
               Oli.ScopedFeatureFlags.Audited.remove_feature(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 :mcp_authoring,
                 project
               )

      # Check that an audit log entry was created; enabling the feature recorded its own event.
      assert [event] = Auditing.list_events(event_type: :feature_flag_removed)
      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.details["feature_name"] == "mcp_authoring"
      assert event.details["enabled"] == nil
      assert event.details["resource_type"] == "project"
    end

    test "returns not found when removing non-existent feature from wrong scope" do
      user = insert(:user)
      section = insert(:section)

      # mcp_authoring doesn't exist for sections, so should return not found
      assert {:error, :not_found} =
               Oli.ScopedFeatureFlags.Audited.remove_feature(
                 Oli.Auditing.Context.for_actor(user, source: :ui),
                 :mcp_authoring,
                 section
               )

      # Check that no audit log entry was created for failed operation
      events = Auditing.list_events()
      assert length(events) == 0
    end

    test "returns error when trying to remove non-existent feature" do
      author = insert(:author)
      project = insert(:project)

      assert {:error, :not_found} =
               Oli.ScopedFeatureFlags.Audited.remove_feature(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 :mcp_authoring,
                 project
               )

      # Check that no audit log entry was created for failed removal
      events = Auditing.list_events()
      assert length(events) == 0
    end
  end

  describe "set_features_atomically audit logging" do
    test "logs multiple feature changes for project" do
      author = insert(:author)
      project = insert(:project)

      feature_settings = [
        {"mcp_authoring", true}
      ]

      assert {:ok, _flag_states} =
               Oli.ScopedFeatureFlags.Audited.set_features_atomically(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 feature_settings,
                 project
               )

      # Check that audit log entries were created
      events = Auditing.list_events(order_by: [asc: :inserted_at])
      assert length(events) == 1

      event = List.first(events)
      assert event.event_type == :feature_flag_enabled
      assert event.author_id == author.id
      assert event.project_id == project.id
      assert event.details["feature_name"] == "mcp_authoring"
      assert event.details["enabled"] == true
      assert event.details["resource_type"] == "project"
    end

    test "validates scope constraints for set_features_atomically" do
      user = insert(:user)
      section = insert(:section)

      feature_settings = [
        {"mcp_authoring", true}
      ]

      # Should fail due to scope constraint
      assert {:error, %{invalid_scope: [error_msg]}} =
               Oli.ScopedFeatureFlags.Audited.set_features_atomically(
                 Oli.Auditing.Context.for_actor(user, source: :ui),
                 feature_settings,
                 section
               )

      assert error_msg =~ "does not support scope 'delivery'"

      # Check that no audit log entries were created due to validation failure
      events = Auditing.list_events()
      assert length(events) == 0
    end

    test "does not log when transaction fails" do
      author = insert(:author)
      project = insert(:project)

      # Use an invalid feature name to cause transaction failure
      feature_settings = [
        {"invalid_feature", true}
      ]

      assert {:error, _changeset} =
               Oli.ScopedFeatureFlags.Audited.set_features_atomically(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 feature_settings,
                 project
               )

      # Check that no audit log entries were created due to transaction rollback
      events = Auditing.list_events()
      assert length(events) == 0
    end
  end

  describe "audit log event descriptions" do
    test "event_description returns proper description for feature flag events" do
      # Test enabled event
      enabled_event = %LogEvent{
        event_type: :feature_flag_enabled,
        details: %{"feature_name" => "mcp_authoring", "resource_type" => "project"}
      }

      assert LogEvent.event_description(enabled_event) ==
               "Enabled feature flag 'mcp_authoring' for project"

      # Test disabled event
      disabled_event = %LogEvent{
        event_type: :feature_flag_disabled,
        details: %{"feature_name" => "mcp_authoring", "resource_type" => "section"}
      }

      assert LogEvent.event_description(disabled_event) ==
               "Disabled feature flag 'mcp_authoring' for section"

      # Test removed event
      removed_event = %LogEvent{
        event_type: :feature_flag_removed,
        details: %{"feature_name" => "mcp_authoring", "resource_type" => "project"}
      }

      assert LogEvent.event_description(removed_event) ==
               "Removed feature flag 'mcp_authoring' from project"
    end
  end

  describe "audit log with resource titles" do
    test "includes project title in audit details when available" do
      author = insert(:author)
      project = insert(:project, title: "Test Project")

      assert {:ok, _flag_state} =
               Oli.ScopedFeatureFlags.Audited.enable_feature(
                 Oli.Auditing.Context.for_actor(author, source: :ui),
                 :mcp_authoring,
                 project
               )

      # Check that audit log includes project title
      events = Auditing.list_events()
      assert length(events) == 1

      event = List.first(events)
      assert event.details["project_title"] == "Test Project"
    end

    test "validates section audit attempts fail with scope constraints" do
      user = insert(:user)
      section = insert(:section, title: "Test Section")

      # Should fail due to scope constraint
      assert {:error, %{invalid_scope: [error_msg]}} =
               Oli.ScopedFeatureFlags.Audited.enable_feature(
                 Oli.Auditing.Context.for_actor(user, source: :ui),
                 :mcp_authoring,
                 section
               )

      assert error_msg =~ "does not support scope 'delivery'"

      # Check that no audit log entries were created
      events = Auditing.list_events()
      assert length(events) == 0
    end
  end

  describe "backward compatibility" do
    test "enable_feature still works with 2 arguments (no actor)" do
      project = insert(:project)

      # This should work without breaking - just no audit logging
      assert {:ok, _flag_state} =
               Oli.ScopedFeatureFlags.Audited.enable_feature(
                 Oli.TestHelpers.audit_context(),
                 :mcp_authoring,
                 project
               )

      # Verify the feature is enabled
      assert ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "disable_feature still works with 2 arguments (no actor)" do
      project = insert(:project)

      # Enable first
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.TestHelpers.audit_context(),
          :mcp_authoring,
          project
        )

      # This should work without breaking - just no audit logging
      assert {:ok, _flag_state} =
               Oli.ScopedFeatureFlags.Audited.disable_feature(
                 Oli.TestHelpers.audit_context(),
                 :mcp_authoring,
                 project
               )

      # Verify the feature is disabled
      refute ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "remove_feature still works with 2 arguments (no actor)" do
      project = insert(:project)

      # Enable first
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.TestHelpers.audit_context(),
          :mcp_authoring,
          project
        )

      # This should work without breaking - just no audit logging
      assert {:ok, _deleted_state} =
               Oli.ScopedFeatureFlags.Audited.remove_feature(
                 Oli.TestHelpers.audit_context(),
                 :mcp_authoring,
                 project
               )

      # Verify the feature is no longer tracked
      refute ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "set_features_atomically still works with 2 arguments (no actor)" do
      project = insert(:project)

      feature_settings = [{"mcp_authoring", true}]

      # This should work without breaking - just no audit logging
      assert {:ok, _flag_states} =
               Oli.ScopedFeatureFlags.Audited.set_features_atomically(
                 Oli.TestHelpers.audit_context(),
                 feature_settings,
                 project
               )

      # Verify the features are set
      assert ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end
  end
end

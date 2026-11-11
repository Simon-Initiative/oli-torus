defmodule Oli.Auditing.ServiceCommandsTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing.{Changes, Context, Error, LogEvent}
  alias Oli.ScopedFeatureFlags

  setup do
    admin = insert(:author)
    %{admin: admin, context: Context.for_actor(admin, source: :ui)}
  end

  describe "AI services" do
    test "provider keys are recorded only as redaction markers", %{context: context} do
      {:ok, model} =
        Oli.GenAI.Audited.create(context, :registered_model, %{
          name: "Audited model",
          provider: :open_ai,
          model: "gpt-test",
          url_template: "https://api.example.edu",
          api_key: "MARKER-AI-KEY",
          secondary_api_key: "MARKER-AI-KEY-2",
          timeout: 8000,
          recv_timeout: 60000
        })

      {:ok, _} =
        Oli.GenAI.Audited.update(context, :registered_model, model.id, %{
          api_key: "MARKER-AI-KEY-3"
        })

      assert [created, updated] = events(:ai_service_settings_changed)
      assert created.entity_id == "registered_model:#{model.id}"
      assert created.changes["api_key"] == Changes.secret_record()
      assert updated.changes == %{"api_key" => Changes.secret_record()}
      refute inspect([created, updated]) =~ "MARKER-AI-KEY"
    end
  end

  describe "API keys" do
    test "lifecycle and settings are recorded without the key", %{context: context} do
      code = "MARKER-API-KEY-#{System.unique_integer([:positive])}"
      {:ok, key} = Oli.Interop.Audited.create_key(context, code, "Partner integration")

      {:ok, _} =
        Oli.Interop.Audited.update_key_settings(context, key.id, %{"payments_enabled" => false})

      {:ok, _} = Oli.Interop.Audited.set_key_status(context, key.id, :disabled)

      assert [created, settings, disabled] = events(:credential_lifecycle_changed)
      assert created.changes["lifecycle"] == %{"operation" => "set", "after" => "created"}
      assert created.details == %{"hint" => "Partner integration"}
      assert settings.changes["payments_enabled"]["after"] == false
      refute Map.has_key?(settings.changes, "lifecycle")
      assert disabled.changes["lifecycle"]["after"] == "disabled"
      refute inspect([created, settings, disabled]) =~ code
      refute inspect(created) =~ key.hash
    end

    test "fields outside the settings form are rejected", %{context: context} do
      {:ok, key} = Oli.Interop.Audited.create_key(context, Ecto.UUID.generate(), "hint")

      assert {:error, :protected} =
               Oli.Interop.Audited.update_key_settings(context, key.id, %{
                 "hash" => "x",
                 "payments_enabled" => false
               })
    end
  end

  describe "MCP tokens" do
    test "creation, rotation, disabling, and revocation without the token" do
      author = insert(:author)
      project = insert(:project, authors: [author])
      context = Context.for_actor(author, source: :ui)

      {:ok, {token, plaintext}} = Oli.MCP.Audited.create_token(context, author.id, project.id)
      {:ok, {_token, rotated}} = Oli.MCP.Audited.regenerate_token(context, author.id, project.id)
      {:ok, _} = Oli.MCP.Audited.set_token_status(context, token.id, :disabled)
      {:ok, _} = Oli.MCP.Audited.set_token_status(context, token.id, :disabled)
      {:ok, _} = Oli.MCP.Audited.revoke_token(context, token.id)

      events = events(:credential_lifecycle_changed)

      assert Enum.map(events, & &1.changes["lifecycle"]["after"]) ==
               ["created", "rotated", "disabled", "revoked"]

      assert Enum.all?(
               events,
               &(&1.affected_author_id == author.id and &1.project_id == project.id)
             )

      refute inspect(events) =~ plaintext
      refute inspect(events) =~ rotated
      refute inspect(events) =~ token.hint
    end

    test "an author who no longer collaborates cannot create a token" do
      author = insert(:author)
      project = insert(:project)
      context = Context.for_actor(author, source: :ui)

      assert {:error, :unauthorized_project_access} =
               Oli.MCP.Audited.create_token(context, author.id, project.id)

      assert events(:credential_lifecycle_changed) == []
    end
  end

  describe "feature flags and rollouts" do
    test "enabling an enabled flag records nothing", %{context: context} do
      project = insert(:project)

      {:ok, _} = ScopedFeatureFlags.Audited.enable_feature(context, :mcp_authoring, project)
      {:ok, _} = ScopedFeatureFlags.Audited.enable_feature(context, :mcp_authoring, project)

      assert [event] = events(:feature_flag_enabled)
      assert event.project_id == project.id
      assert event.event_key == "flag:mcp_authoring:project_#{project.id}:feature_flag_enabled"
    end

    test "a failing audit insert rolls the flag back", %{context: context} do
      project = insert(:project)
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, %Error{code: :insert_failed}} =
                 ScopedFeatureFlags.Audited.enable_feature(context, :mcp_authoring, project)
      end)

      refute ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "setting the current rollout stage again records nothing", %{context: context} do
      {:ok, _} =
        ScopedFeatureFlags.Audited.upsert_rollout(
          context,
          :canary_test_feature,
          :global,
          nil,
          :five_percent
        )

      {:ok, _} =
        ScopedFeatureFlags.Audited.upsert_rollout(
          context,
          :canary_test_feature,
          :global,
          nil,
          :five_percent
        )

      {:ok, _} =
        ScopedFeatureFlags.Audited.upsert_rollout(
          context,
          :canary_test_feature,
          :global,
          nil,
          :full
        )

      assert [first, second] = events(:feature_rollout_stage_changed)
      assert first.details["stage"] == "five_percent"
      assert second.details["previous"] == %{"stage" => "five_percent", "effect" => nil}
    end
  end

  defp events(event_type),
    do: Repo.all(from(e in LogEvent, where: e.event_type == ^event_type, order_by: e.id))

  defp reject_audit_inserts do
    Repo.query!("""
    CREATE FUNCTION pg_temp.reject_audit_insert() RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'audit insert rejected by test';
    END;
    $$ LANGUAGE plpgsql
    """)

    Repo.query!("""
    CREATE TRIGGER reject_audit_insert BEFORE INSERT ON audit_log_events
      FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_audit_insert()
    """)
  end
end

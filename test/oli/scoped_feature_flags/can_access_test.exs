defmodule Oli.ScopedFeatureFlags.CanAccessTest do
  use Oli.DataCase, async: false

  import Oli.Factory

  alias Oli.ScopedFeatureFlags

  @feature :canary_test_feature

  setup do
    ensure_cache(:feature_flag_stage)
    ensure_cache(:feature_flag_cohorts)

    on_exit(fn ->
      Cachex.clear(:feature_flag_stage)
      Cachex.clear(:feature_flag_cohorts)
    end)

    project = insert(:project)
    section = insert(:section, base_project: project, publisher: project.publisher)
    author = insert(:author)

    {:ok, project: project, section: section, author: author}
  end

  describe "scoped_only features" do
    test "follow legacy enabled? semantics", %{project: project, author: author} do
      handler = attach_decision_telemetry()

      refute ScopedFeatureFlags.can_access?(:mcp_authoring, author, project)

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          :mcp_authoring,
          project
        )

      assert ScopedFeatureFlags.can_access?(:mcp_authoring, author, project)

      {:ok, diagnostics} =
        ScopedFeatureFlags.can_access?(:mcp_authoring, author, project, diagnostics: true)

      assert diagnostics.mode == :scoped_only
      assert diagnostics.stage == :full

      :telemetry.detach(handler)
    end
  end

  describe "canary features" do
    setup %{project: project, author: author} do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          project
        )

      {:ok, internal_author: insert(:author, is_internal: true)}
    end

    test "internal-only stage allows internal actors", %{
      project: project,
      author: author,
      internal_author: internal_author
    } do
      handler = attach_decision_telemetry()

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :internal_only
        )

      refute ScopedFeatureFlags.can_access?(@feature, author, project)
      assert ScopedFeatureFlags.can_access?(@feature, internal_author, project)

      {:ok, diagnostics} =
        ScopedFeatureFlags.can_access?(@feature, author, project, diagnostics: true)

      assert diagnostics.stage == :internal_only
      assert diagnostics.reason == :not_internal

      :telemetry.detach(handler)
    end

    test "force_enable exemption overrides percentage stage", %{
      project: project,
      author: author
    } do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :five_percent
        )

      student = insert(:user, is_internal: false)

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_exemption(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          project.publisher_id,
          :force_enable
        )

      assert ScopedFeatureFlags.can_access?(@feature, student, project)

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :off
        )

      refute ScopedFeatureFlags.can_access?(@feature, student, project)
    end

    test "deny exemption blocks access in full stage", %{
      project: project,
      author: author
    } do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :full
        )

      student = insert(:user, is_internal: false)

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_exemption(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          project.publisher_id,
          :deny
        )

      refute ScopedFeatureFlags.can_access?(@feature, student, project)
    end

    test "cohort caching stores and invalidates decisions", %{
      project: project,
      author: author
    } do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :fifty_percent
        )

      student = insert(:user, is_internal: false)

      ScopedFeatureFlags.can_access?(@feature, student, project)

      assert {:ok, %{stage: :fifty_percent}} =
               Cachex.get(:feature_flag_cohorts, {
                 :cohort,
                 "canary_test_feature",
                 :user,
                 student.id
               })

      ScopedFeatureFlags.handle_pubsub_message(
        {:stage_invalidated, "canary_test_feature", :project, project.id}
      )

      assert {:ok, nil} ==
               Cachex.get(:feature_flag_stage, {
                 :stage,
                 "canary_test_feature",
                 :project,
                 project.id
               })
    end

    test "diagnostics flag returns extended data", %{
      project: project,
      author: author
    } do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :fifty_percent
        )

      student = insert(:user, is_internal: false)

      {:ok, diagnostics} =
        ScopedFeatureFlags.can_access?(@feature, student, project, diagnostics: true)

      assert diagnostics.feature == "canary_test_feature"
      assert diagnostics.scope.scope_type == :project
      assert diagnostics.hash_version == 1
    end

    test "section scope inherits project rollout", %{
      section: section,
      author: author,
      project: project
    } do
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          section
        )

      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.upsert_rollout(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          @feature,
          :project,
          project.id,
          :full
        )

      student = insert(:user, is_internal: false)

      assert ScopedFeatureFlags.can_access?(@feature, student, section)
    end
  end

  defp ensure_cache(name) do
    case Process.whereis(name) do
      nil -> start_supervised!({Cachex, name: name})
      _pid -> :ok
    end
  end

  defp attach_decision_telemetry do
    handler_id = :"canary_decision_#{System.unique_integer([:positive, :monotonic])}"
    parent = self()

    :telemetry.attach(
      handler_id,
      [:torus, :feature_flag, :decision],
      fn event, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end
end

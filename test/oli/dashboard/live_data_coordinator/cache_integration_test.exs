defmodule Oli.Dashboard.LiveDataCoordinator.CacheIntegrationTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.LiveDataCoordinator

  setup do
    inprocess_store = start_supervised!({InProcessStore, enrollment_count: 100})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 901,
      user_id: 1101,
      scope: %{container_type: :course}
    }

    scope = %{container_type: :container, container_id: 3101}
    key_meta = %{oracle_version: 1, data_version: 1}

    cache_opts = [inprocess_store: inprocess_store, key_meta: key_meta]
    coordinator_opts = [context: context, cache_opts: cache_opts]

    %{
      inprocess_store: inprocess_store,
      context: context,
      scope: scope,
      key_meta: key_meta,
      cache_opts: cache_opts,
      coordinator_opts: coordinator_opts
    }
  end

  describe "cache consult-first action shaping" do
    test "full hit emits immediate required-ready with no runtime start", %{
      context: context,
      scope: scope,
      key_meta: key_meta,
      cache_opts: cache_opts,
      coordinator_opts: coordinator_opts
    } do
      # @ac "AC-003"
      assert :ok =
               Cache.write_oracle(context, scope, :progress, %{value: 81}, key_meta, cache_opts)

      assert :ok =
               Cache.write_oracle(context, scope, :objectives, %{value: 63}, key_meta, cache_opts)

      initial = LiveDataCoordinator.new_session(timeout_ms: 8_000)

      assert {:ok, _next_state, actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 scope,
                 %{required: [:progress, :objectives], optional: []},
                 coordinator_opts
               )

      assert Enum.map(actions, & &1.type) == [
               :request_started,
               :timeout_scheduled,
               :cache_consulted,
               :emit_required_ready,
               :timeout_cancelled,
               :request_completed
             ]

      assert %{type: :cache_consulted, cache_outcome: :full_hit, misses: []} = Enum.at(actions, 2)

      assert %{
               type: :emit_required_ready,
               hits: %{progress: %{value: 81}, objectives: %{value: 63}}
             } = Enum.at(actions, 3)
    end

    test "partial hit emits required-ready for hits and runtime start for misses", %{
      context: context,
      scope: scope,
      key_meta: key_meta,
      cache_opts: cache_opts,
      coordinator_opts: coordinator_opts
    } do
      # @ac "AC-003"
      assert :ok =
               Cache.write_oracle(context, scope, :progress, %{value: 88}, key_meta, cache_opts)

      initial = LiveDataCoordinator.new_session()

      assert {:ok, _next_state, actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 scope,
                 %{required: [:progress, :objectives], optional: []},
                 coordinator_opts
               )

      assert Enum.map(actions, & &1.type) == [
               :request_started,
               :timeout_scheduled,
               :cache_consulted,
               :emit_required_ready,
               :emit_loading,
               :runtime_start
             ]

      assert %{type: :cache_consulted, cache_outcome: :partial_hit, misses: [:objectives]} =
               Enum.at(actions, 2)

      assert %{type: :emit_required_ready, hits: %{progress: %{value: 88}}} = Enum.at(actions, 3)
      assert %{type: :emit_loading, misses: [:objectives]} = Enum.at(actions, 4)
      assert %{type: :runtime_start, misses: [:objectives]} = Enum.at(actions, 5)
    end

    test "cache miss emits runtime start for required misses only", %{
      scope: scope,
      coordinator_opts: coordinator_opts
    } do
      # @ac "AC-003"
      initial = LiveDataCoordinator.new_session()

      assert {:ok, _next_state, actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 scope,
                 %{required: [:progress, :objectives], optional: [:support]},
                 coordinator_opts
               )

      assert Enum.map(actions, & &1.type) == [
               :request_started,
               :timeout_scheduled,
               :cache_consulted,
               :emit_loading,
               :runtime_start
             ]

      assert %{type: :cache_consulted, cache_outcome: :miss, misses: [:progress, :objectives]} =
               Enum.at(actions, 2)

      assert %{type: :emit_loading, misses: [:progress, :objectives]} = Enum.at(actions, 3)
      assert %{type: :runtime_start, misses: [:progress, :objectives]} = Enum.at(actions, 4)
    end
  end
end

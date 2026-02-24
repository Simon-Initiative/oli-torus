defmodule Oli.Dashboard.LiveDataCoordinator.RequestScopeChangeTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.LiveDataCoordinator.State

  defmodule FakeCache do
    def lookup_required(_context, _scope, _required_oracles, opts) do
      Keyword.fetch!(opts, :lookup_result)
    end
  end

  setup do
    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 700,
      user_id: 1001,
      scope: %{container_type: :course}
    }

    %{context: context}
  end

  describe "request queue intake" do
    test "rapid scope cycling keeps one active and one latest queued request", %{context: context} do
      # @ac "AC-001"
      initial = LiveDataCoordinator.new_session(timeout_ms: 9_000)

      opts = [
        context: context,
        cache_module: FakeCache,
        cache_opts: [lookup_result: {:ok, %{hits: %{}, misses: [:progress], source: :none}}]
      ]

      assert {:ok, first_state, first_actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 %{container_type: :container, container_id: 101},
                 %{required: [:progress], optional: []},
                 opts
               )

      assert Enum.map(first_actions, & &1.type) == [
               :request_started,
               :timeout_scheduled,
               :cache_consulted,
               :emit_loading,
               :runtime_start
             ]

      assert %{type: :cache_consulted, cache_outcome: :miss, misses: [:progress]} =
               Enum.at(first_actions, 2)

      assert {:ok, second_state, second_actions} =
               LiveDataCoordinator.request_scope_change(
                 first_state,
                 %{container_type: :container, container_id: 102},
                 %{required: [:objectives], optional: []},
                 opts
               )

      assert Enum.map(second_actions, & &1.type) == [:request_queued]
      assert second_state.active_request.request_token == 1
      assert second_state.queued_request.request_token == 2
      assert State.in_flight?(second_state)
      assert State.queued?(second_state)

      assert {:ok, third_state, third_actions} =
               LiveDataCoordinator.request_scope_change(
                 second_state,
                 %{container_type: :container, container_id: 103},
                 %{required: [:assessments], optional: []},
                 opts
               )

      assert Enum.map(third_actions, & &1.type) == [:request_queue_replaced]
      assert third_state.active_request.request_token == 1
      assert third_state.queued_request.request_token == 3
      assert third_state.next_request_token == 4
    end
  end

  describe "request input validation and fallback shaping" do
    test "missing context is rejected with deterministic error and no state mutation" do
      initial = LiveDataCoordinator.new_session()

      assert {:error, {:invalid_transition, :missing_context}, returned_state,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 %{container_type: :course},
                 %{required: [:progress], optional: []}
               )

      assert returned_state == initial
    end

    test "invalid context is rejected with deterministic error and state preservation" do
      initial = LiveDataCoordinator.new_session()

      invalid_context = %{
        dashboard_context_type: :section,
        dashboard_context_id: nil,
        user_id: 1001,
        scope: %{container_type: :course}
      }

      assert {:error, {:invalid_transition, :invalid_context}, returned_state,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 %{container_type: :course},
                 %{required: [:progress], optional: []},
                 context: invalid_context,
                 cache_module: FakeCache,
                 cache_opts: [
                   lookup_result: {:ok, %{hits: %{}, misses: [:progress], source: :none}}
                 ]
               )

      assert returned_state == initial
    end

    test "cache lookup errors degrade to miss + runtime start actions", %{context: context} do
      initial = LiveDataCoordinator.new_session()

      assert {:ok, _next_state, actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 %{container_type: :container, container_id: 201},
                 %{required: [:progress, :objectives], optional: []},
                 context: context,
                 cache_module: FakeCache,
                 cache_opts: [lookup_result: {:error, :cache_unavailable}]
               )

      assert Enum.map(actions, & &1.type) == [
               :request_started,
               :timeout_scheduled,
               :cache_consulted,
               :emit_loading,
               :runtime_start
             ]

      assert %{type: :cache_consulted, cache_outcome: :error, misses: [:progress, :objectives]} =
               Enum.at(actions, 2)

      assert %{type: :runtime_start, misses: [:progress, :objectives]} = Enum.at(actions, 4)
    end
  end
end

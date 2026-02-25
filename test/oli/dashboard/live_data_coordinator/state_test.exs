defmodule Oli.Dashboard.LiveDataCoordinator.StateTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.LiveDataCoordinator.State

  defp context do
    %{
      dashboard_context_type: :section,
      dashboard_context_id: 501,
      user_id: 1001,
      scope: %{container_type: :course}
    }
  end

  describe "session lifecycle helpers" do
    test "new session starts idle with deterministic defaults" do
      state = LiveDataCoordinator.new_session()

      assert State.idle?(state)
      refute State.in_flight?(state)
      refute State.queued?(state)
      assert state.next_request_token == 1
      assert state.timeout_ms == 30_000
      assert state.scrub_window_ms == 400
      assert state.scrub_threshold == 3
    end

    test "new session accepts explicit timeout override" do
      state = LiveDataCoordinator.new_session(timeout_ms: 12_345)
      assert state.timeout_ms == 12_345
    end
  end

  describe "request scope-change transitions" do
    test "idle request becomes active and schedules timeout action" do
      initial = LiveDataCoordinator.new_session(timeout_ms: 9_000)

      assert {:ok, next, actions} =
               LiveDataCoordinator.request_scope_change(
                 initial,
                 %{container_type: :course},
                 %{required: [:progress], optional: []},
                 context: context()
               )

      assert State.in_flight?(next)
      refute State.queued?(next)
      assert next.active_request.request_token == 1
      assert next.next_request_token == 2
      assert next.active_request.scope.container_type == :course
      assert next.active_request.scope.container_id == nil

      assert [
               %{
                 type: :request_started,
                 request_token: 1,
                 dependency_profile: %{required: [:progress], optional: []}
               },
               %{type: :timeout_scheduled, request_token: 1, timeout_ms: 9_000}
               | _
             ] = actions
    end

    test "in-flight requests enqueue latest intent and then replace queued request deterministically in scrub mode" do
      initial = LiveDataCoordinator.new_session(scrub_threshold: 2)

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          initial,
          %{container_type: :container, container_id: 10},
          %{required: [:progress], optional: []},
          context: context()
        )

      assert {:ok, queued, [%{type: :request_queued, request_token: 2}]} =
               LiveDataCoordinator.request_scope_change(
                 in_flight,
                 %{container_type: :container, container_id: 11},
                 %{required: [:objectives], optional: [:support]},
                 context: context()
               )

      assert queued.active_request.request_token == 1
      assert queued.queued_request.request_token == 2
      assert queued.next_request_token == 3

      assert {:ok, replaced,
              [%{type: :request_queue_replaced, request_token: 3, replaced_request_token: 2}]} =
               LiveDataCoordinator.request_scope_change(
                 queued,
                 %{container_type: :container, container_id: 12},
                 %{required: [:assessments], optional: []},
                 context: context()
               )

      assert replaced.active_request.request_token == 1
      assert replaced.queued_request.request_token == 3
      assert replaced.next_request_token == 4
    end

    test "outside scrub mode latest scope change preempts active request immediately" do
      initial = LiveDataCoordinator.new_session(scrub_threshold: 3)

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          initial,
          %{container_type: :container, container_id: 10},
          %{required: [:progress], optional: []},
          context: context()
        )

      assert {:ok, next_state, actions} =
               LiveDataCoordinator.request_scope_change(
                 in_flight,
                 %{container_type: :container, container_id: 11},
                 %{required: [:objectives], optional: []},
                 context: context()
               )

      assert Enum.take(Enum.map(actions, & &1.type), 3) == [
               :timeout_cancelled,
               :request_started,
               :timeout_scheduled
             ]

      assert next_state.active_request.request_token == 2
      refute State.queued?(next_state)
      assert Map.has_key?(next_state.retired_requests, 1)
    end

    test "invalid scope returns deterministic transition error and preserves state" do
      state = LiveDataCoordinator.new_session(scrub_threshold: 2)

      assert {:error, {:invalid_scope, _reason}, returned_state, [%{type: :invalid_transition}]} =
               LiveDataCoordinator.request_scope_change(
                 state,
                 %{container_type: :unknown, container_id: 1},
                 %{required: [], optional: []},
                 context: context()
               )

      assert returned_state == state
    end

    test "invalid dependency profile returns deterministic transition error and preserves state" do
      state = LiveDataCoordinator.new_session(scrub_threshold: 2)

      assert {:error, {:invalid_dependency_profile, _reason}, returned_state,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.request_scope_change(
                 state,
                 %{container_type: :course},
                 %{required: [:progress], unsupported: [:objectives]},
                 context: context()
               )

      assert returned_state == state
    end
  end

  describe "oracle result and timeout hooks" do
    test "invalid state payloads return deterministic invalid-state transition errors" do
      reason = {:invalid_transition, {:invalid_state, %{not: :state}}}

      assert {:error, ^reason, returned_state, [%{type: :invalid_transition, reason: ^reason}]} =
               LiveDataCoordinator.request_scope_change(
                 %{not: :state},
                 %{container_type: :course},
                 %{required: [], optional: []},
                 context: context()
               )

      assert State.idle?(returned_state)

      assert {:error, ^reason, ^returned_state, [%{type: :invalid_transition, reason: ^reason}]} =
               LiveDataCoordinator.handle_oracle_result(
                 %{not: :state},
                 1,
                 :progress,
                 %{value: 1}
               )

      assert {:error, ^reason, ^returned_state, [%{type: :invalid_transition, reason: ^reason}]} =
               LiveDataCoordinator.handle_request_timeout(%{not: :state}, 1)
    end

    test "oracle result without active request is rejected deterministically" do
      state = LiveDataCoordinator.new_session()

      assert {:error, {:invalid_transition, {:unknown_request_token, 1}}, returned_state,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.handle_oracle_result(state, 1, :progress, %{value: 1})

      assert returned_state == state
    end

    test "oracle results classify active, queued, stale, and unknown tokens deterministically" do
      state = LiveDataCoordinator.new_session(scrub_threshold: 2)

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          state,
          %{container_type: :container, container_id: 20},
          %{required: [:progress], optional: []},
          context: context()
        )

      {:ok, queued, _actions} =
        LiveDataCoordinator.request_scope_change(
          in_flight,
          %{container_type: :container, container_id: 21},
          %{required: [:objectives], optional: []},
          context: context()
        )

      assert {:error, {:invalid_transition, {:queued_result_not_allowed, 2}}, ^queued,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.handle_oracle_result(queued, 2, :objectives, %{value: 64})

      assert {:ok, promoted, active_actions} =
               LiveDataCoordinator.handle_oracle_result(queued, 1, :progress, %{value: 80})

      assert Enum.any?(active_actions, fn
               %{type: :oracle_result_received, token_state: :active, request_token: 1} -> true
               _ -> false
             end)

      assert Enum.any?(active_actions, fn
               %{type: :request_promoted, request_token: 2} -> true
               _ -> false
             end)

      assert promoted.active_request.request_token == 2
      refute State.queued?(promoted)

      assert {:ok, ^promoted, stale_actions} =
               LiveDataCoordinator.handle_oracle_result(promoted, 1, :progress, %{value: 81})

      assert Enum.any?(stale_actions, fn
               %{type: :oracle_result_received, token_state: :stale, request_token: 1} -> true
               _ -> false
             end)

      assert Enum.any?(stale_actions, fn
               %{type: :stale_result_suppressed, request_token: 1} -> true
               _ -> false
             end)

      assert {:error, {:invalid_transition, {:unknown_request_token, 999}}, ^promoted,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.handle_oracle_result(promoted, 999, :progress, %{value: 1})
    end

    test "timeout hooks accept active token and reject unknown tokens" do
      state = LiveDataCoordinator.new_session()

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          state,
          %{container_type: :container, container_id: 30},
          %{required: [:progress], optional: []},
          context: context()
        )

      assert {:ok, timed_out_state, timeout_actions} =
               LiveDataCoordinator.handle_request_timeout(in_flight, 1)

      assert Enum.map(timeout_actions, & &1.type) == [
               :timeout_fired,
               :emit_timeout_fallback,
               :emit_failure,
               :request_timed_out
             ]

      assert State.idle?(timed_out_state)

      assert {:error, {:invalid_transition, {:unknown_request_token, 2}}, ^in_flight,
              [%{type: :invalid_transition}]} =
               LiveDataCoordinator.handle_request_timeout(in_flight, 2)
    end
  end
end

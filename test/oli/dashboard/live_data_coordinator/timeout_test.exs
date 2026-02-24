defmodule Oli.Dashboard.LiveDataCoordinator.TimeoutTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.LiveDataCoordinator.State

  defmodule StubCache do
    def lookup_required(_context, scope, required_oracles, opts) do
      lookup_fun = Keyword.fetch!(opts, :lookup_fun)
      lookup_fun.(scope, required_oracles)
    end
  end

  setup do
    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 611,
      user_id: 1001,
      scope: %{container_type: :course}
    }

    lookup_fun = fn _scope, required_oracles ->
      {:ok, %{hits: %{}, misses: required_oracles, source: :none}}
    end

    opts = [
      context: context,
      cache_module: StubCache,
      cache_opts: [lookup_fun: lookup_fun]
    ]

    %{opts: opts}
  end

  test "timeout emits deterministic fallback, promotes queued request, and starts promoted load",
       %{
         opts: opts
       } do
    # @ac "AC-008"
    initial = LiveDataCoordinator.new_session(timeout_ms: 4_200)

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 4101},
        %{required: [:progress, :objectives], optional: []},
        opts
      )

    {:ok, queued, _actions} =
      LiveDataCoordinator.request_scope_change(
        in_flight,
        %{container_type: :container, container_id: 4102},
        %{required: [:assessments], optional: []},
        opts
      )

    assert {:ok, timed_out_state, actions} =
             LiveDataCoordinator.handle_request_timeout(queued, 1, opts)

    assert Enum.map(actions, & &1.type) == [
             :timeout_fired,
             :emit_timeout_fallback,
             :emit_failure,
             :emit_failure,
             :request_timed_out,
             :request_promoted,
             :timeout_scheduled,
             :cache_consulted,
             :emit_loading,
             :runtime_start
           ]

    assert timed_out_state.active_request.request_token == 2
    assert State.in_flight?(timed_out_state)
    refute State.queued?(timed_out_state)
  end

  test "timeout fallback without queued request returns idle and remains responsive to next request",
       %{
         opts: opts
       } do
    # @ac "AC-008"
    initial = LiveDataCoordinator.new_session(timeout_ms: 4_200)

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 4201},
        %{required: [:progress], optional: []},
        opts
      )

    assert {:ok, timed_out_state, timeout_actions} =
             LiveDataCoordinator.handle_request_timeout(in_flight, 1, opts)

    assert Enum.map(timeout_actions, & &1.type) == [
             :timeout_fired,
             :emit_timeout_fallback,
             :emit_failure,
             :request_timed_out
           ]

    assert State.idle?(timed_out_state)

    assert {:ok, resumed_state, resumed_actions} =
             LiveDataCoordinator.request_scope_change(
               timed_out_state,
               %{container_type: :container, container_id: 4202},
               %{required: [:assessments], optional: []},
               opts
             )

    assert State.in_flight?(resumed_state)

    assert Enum.take(Enum.map(resumed_actions, & &1.type), 2) == [
             :request_started,
             :timeout_scheduled
           ]
  end
end

defmodule Oli.Dashboard.LiveDataCoordinator.StaleSuppressionTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.LiveDataCoordinator.State

  defmodule StubCache do
    def lookup_required(_context, scope, required_oracles, opts) do
      lookup_fun = Keyword.fetch!(opts, :lookup_fun)
      lookup_fun.(scope, required_oracles)
    end

    def write_oracle(context, scope, oracle_key, payload, _meta, opts) do
      if sink = Keyword.get(opts, :write_sink) do
        Agent.update(sink, fn writes ->
          [
            %{context: context, scope: scope, oracle_key: oracle_key, payload: payload}
            | writes
          ]
        end)
      end

      :ok
    end
  end

  setup do
    write_sink = start_supervised!({Agent, fn -> [] end})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 901,
      user_id: 1001,
      scope: %{container_type: :course}
    }

    lookup_fun = fn _scope, required_oracles ->
      {:ok, %{hits: %{}, misses: required_oracles, source: :none}}
    end

    opts = [
      context: context,
      cache_module: StubCache,
      cache_opts: [lookup_fun: lookup_fun, write_sink: write_sink]
    ]

    %{context: context, opts: opts, write_sink: write_sink}
  end

  test "stale completion suppresses UI actions and still warms cache via stale-safe write", %{
    opts: opts,
    write_sink: write_sink
  } do
    # @ac "AC-002"
    # @ac "AC-004"
    # @ac "AC-007"
    initial = LiveDataCoordinator.new_session(timeout_ms: 5_000, scrub_threshold: 2)

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 3101},
        %{required: [:progress], optional: []},
        opts
      )

    {:ok, queued, _actions} =
      LiveDataCoordinator.request_scope_change(
        in_flight,
        %{container_type: :container, container_id: 3102},
        %{required: [:objectives], optional: []},
        opts
      )

    {:ok, promoted, _actions} =
      LiveDataCoordinator.handle_oracle_result(
        queued,
        1,
        :progress,
        %{status: :ok, payload: %{value: 70}},
        opts
      )

    Agent.update(write_sink, fn _writes -> [] end)

    assert {:ok, next_state, stale_actions} =
             LiveDataCoordinator.handle_oracle_result(
               promoted,
               1,
               :progress,
               %{status: :ok, payload: %{value: 71}},
               opts
             )

    assert Enum.map(stale_actions, & &1.type) == [
             :oracle_result_received,
             :stale_result_suppressed,
             :cache_write
           ]

    assert %{type: :cache_write, token_state: :stale, write_mode: :late, outcome: :accepted} =
             Enum.find(stale_actions, &(&1.type == :cache_write))

    refute Enum.any?(stale_actions, &(&1.type == :emit_oracle_ready))
    refute Enum.any?(stale_actions, &(&1.type == :emit_failure))

    assert next_state.active_request.request_token == 2
    assert State.in_flight?(next_state)

    assert [%{scope: %{container_id: 3101}, payload: %{value: 71}}] = Agent.get(write_sink, & &1)
  end
end

defmodule Oli.Dashboard.LiveDataCoordinator.ResultHandlingTest do
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
      dashboard_context_id: 811,
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

  describe "active oracle result handling" do
    test "active required result completes current request, promotes queued request, and starts promoted flow",
         %{opts: opts, write_sink: write_sink} do
      # @ac "AC-007"
      initial = LiveDataCoordinator.new_session(timeout_ms: 4_000, scrub_threshold: 2)

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          initial,
          %{container_type: :container, container_id: 2101},
          %{required: [:progress], optional: []},
          opts
        )

      {:ok, queued, _actions} =
        LiveDataCoordinator.request_scope_change(
          in_flight,
          %{container_type: :container, container_id: 2102},
          %{required: [:objectives], optional: []},
          opts
        )

      assert {:ok, next_state, actions} =
               LiveDataCoordinator.handle_oracle_result(
                 queued,
                 1,
                 :progress,
                 %{status: :ok, payload: %{value: 81}, oracle_version: 2},
                 opts
               )

      assert Enum.map(actions, & &1.type) == [
               :oracle_result_received,
               :emit_oracle_ready,
               :timeout_cancelled,
               :request_completed,
               :request_promoted,
               :timeout_scheduled,
               :cache_write,
               :cache_consulted,
               :emit_loading,
               :runtime_start
             ]

      assert next_state.active_request.request_token == 2
      assert State.in_flight?(next_state)
      refute State.queued?(next_state)

      assert [%{oracle_key: :progress, scope: %{container_id: 2101}, payload: %{value: 81}}] =
               Agent.get(write_sink, & &1)
    end

    test "required dependency failure emits scoped failure and completes deterministically", %{
      opts: opts,
      write_sink: write_sink
    } do
      initial = LiveDataCoordinator.new_session()

      {:ok, in_flight, _actions} =
        LiveDataCoordinator.request_scope_change(
          initial,
          %{container_type: :container, container_id: 2201},
          %{required: [:progress], optional: []},
          opts
        )

      assert {:ok, next_state, actions} =
               LiveDataCoordinator.handle_oracle_result(
                 in_flight,
                 1,
                 :progress,
                 %{status: :error, reason: :oracle_timeout},
                 opts
               )

      assert Enum.map(actions, & &1.type) == [
               :oracle_result_received,
               :emit_failure,
               :timeout_cancelled,
               :request_completed,
               :cache_write
             ]

      assert %{type: :cache_write, outcome: :skipped, reason: :oracle_error} =
               Enum.find(actions, &(&1.type == :cache_write))

      assert State.idle?(next_state)
      assert Agent.get(write_sink, & &1) == []
    end
  end
end

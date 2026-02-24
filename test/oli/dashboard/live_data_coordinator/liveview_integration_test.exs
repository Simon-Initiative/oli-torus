defmodule Oli.Dashboard.LiveDataCoordinator.LiveViewIntegrationTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator

  defmodule HarnessCache do
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

  defmodule LiveViewHarnessAdapter do
    alias Oli.Dashboard.LiveDataCoordinator

    def new(opts, coordinator_state \\ nil) do
      %{
        coordinator_state:
          coordinator_state || LiveDataCoordinator.new_session(timeout_ms: 3_500),
        opts: opts,
        active_token: nil,
        loading: [],
        ready: %{},
        failures: %{},
        timeout_fallback: nil,
        timers: %{},
        applied: []
      }
    end

    def request_scope(harness, scope, dependency_profile) do
      transition(harness, fn state, opts ->
        LiveDataCoordinator.request_scope_change(state, scope, dependency_profile, opts)
      end)
    end

    def oracle_result(harness, request_token, oracle_key, oracle_result) do
      transition(harness, fn state, opts ->
        LiveDataCoordinator.handle_oracle_result(
          state,
          request_token,
          oracle_key,
          oracle_result,
          opts
        )
      end)
    end

    def timeout(harness, request_token) do
      transition(harness, fn state, opts ->
        LiveDataCoordinator.handle_request_timeout(state, request_token, opts)
      end)
    end

    defp transition(harness, transition_fun) do
      case transition_fun.(harness.coordinator_state, harness.opts) do
        {:ok, next_state, actions} ->
          next_harness =
            %{harness | coordinator_state: next_state}
            |> apply_actions(actions)

          {next_harness, actions}

        {:error, reason, _state, _actions} ->
          raise "unexpected coordinator transition failure in test harness: #{inspect(reason)}"
      end
    end

    defp apply_actions(harness, actions) do
      Enum.reduce(actions, harness, fn action, acc -> apply_action(action, acc) end)
    end

    defp apply_action(%{type: :request_started, request_token: request_token} = action, harness) do
      harness
      |> put_active_scope(request_token)
      |> append_applied(action)
    end

    defp apply_action(%{type: :request_promoted, request_token: request_token} = action, harness) do
      harness
      |> put_active_scope(request_token)
      |> append_applied(action)
    end

    defp apply_action(
           %{type: :timeout_scheduled, request_token: request_token, timeout_ms: timeout_ms} =
             action,
           harness
         ) do
      harness
      |> put_in([:timers, request_token], timeout_ms)
      |> append_applied(action)
    end

    defp apply_action(%{type: :timeout_fired, request_token: request_token} = action, harness) do
      harness
      |> update_in([:timers], &Map.delete(&1, request_token))
      |> append_applied(action)
    end

    defp apply_action(%{type: :timeout_cancelled, request_token: request_token} = action, harness) do
      harness
      |> update_in([:timers], &Map.delete(&1, request_token))
      |> append_applied(action)
    end

    defp apply_action(
           %{type: :emit_loading, request_token: request_token, misses: misses} = action,
           harness
         ) do
      if active_token?(harness, request_token) do
        harness
        |> Map.put(:loading, misses)
        |> append_applied(action)
      else
        harness
      end
    end

    defp apply_action(
           %{type: :emit_required_ready, request_token: request_token, hits: hits} = action,
           harness
         ) do
      if active_token?(harness, request_token) do
        harness
        |> Map.put(:ready, Map.merge(harness.ready, hits))
        |> append_applied(action)
      else
        harness
      end
    end

    defp apply_action(
           %{
             type: :emit_oracle_ready,
             request_token: request_token,
             oracle_key: oracle_key,
             payload: payload
           } =
             action,
           harness
         ) do
      if active_token?(harness, request_token) do
        harness
        |> put_in([:ready, oracle_key], payload)
        |> append_applied(action)
      else
        harness
      end
    end

    defp apply_action(
           %{
             type: :emit_failure,
             request_token: request_token,
             oracle_key: oracle_key,
             reason: reason
           } =
             action,
           harness
         ) do
      if active_token?(harness, request_token) do
        harness
        |> put_in([:failures, oracle_key], reason)
        |> append_applied(action)
      else
        harness
      end
    end

    defp apply_action(
           %{type: :emit_timeout_fallback, request_token: request_token, misses: misses} = action,
           harness
         ) do
      if active_token?(harness, request_token) do
        harness
        |> Map.put(:timeout_fallback, %{request_token: request_token, misses: misses})
        |> append_applied(action)
      else
        harness
      end
    end

    defp apply_action(_action, harness), do: harness

    defp put_active_scope(harness, request_token) do
      %{
        harness
        | active_token: request_token,
          loading: [],
          ready: %{},
          failures: %{},
          timeout_fallback: nil
      }
    end

    defp active_token?(harness, request_token), do: harness.active_token == request_token

    defp append_applied(harness, action) do
      %{
        harness
        | applied: harness.applied ++ [Map.take(action, [:type, :request_token, :oracle_key])]
      }
    end
  end

  setup do
    write_sink = start_supervised!({Agent, fn -> [] end})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 731,
      user_id: 1001,
      scope: %{container_type: :course}
    }

    lookup_fun = fn _scope, required_oracles ->
      {:ok, %{hits: %{}, misses: required_oracles, source: :none}}
    end

    opts = [
      context: context,
      cache_module: HarnessCache,
      cache_opts: [lookup_fun: lookup_fun, write_sink: write_sink]
    ]

    %{opts: opts, write_sink: write_sink}
  end

  test "test-only integration harness applies coordinator actions with centralized token guards",
       %{
         opts: opts,
         write_sink: write_sink
       } do
    harness = LiveViewHarnessAdapter.new(opts)

    {h1, _actions} =
      LiveViewHarnessAdapter.request_scope(
        harness,
        %{container_type: :container, container_id: 5101},
        %{required: [:progress], optional: []}
      )

    {h2, _actions} =
      LiveViewHarnessAdapter.request_scope(
        h1,
        %{container_type: :container, container_id: 5102},
        %{required: [:objectives], optional: []}
      )

    {h3, _actions} =
      LiveViewHarnessAdapter.oracle_result(
        h2,
        1,
        :progress,
        %{status: :ok, payload: %{value: 75}}
      )

    assert h3.active_token == 2
    assert h3.loading == [:objectives]

    applied_ready_count_before =
      Enum.count(h3.applied, fn
        %{type: :emit_oracle_ready, request_token: 1} -> true
        _ -> false
      end)

    {h4, stale_actions} =
      LiveViewHarnessAdapter.oracle_result(
        h3,
        1,
        :progress,
        %{status: :ok, payload: %{value: 76}}
      )

    assert Enum.any?(stale_actions, &(&1.type == :stale_result_suppressed))
    assert h4.ready == h3.ready
    assert h4.failures == h3.failures

    applied_ready_count_after =
      Enum.count(h4.applied, fn
        %{type: :emit_oracle_ready, request_token: 1} -> true
        _ -> false
      end)

    assert applied_ready_count_after == applied_ready_count_before

    assert [%{scope: %{container_id: 5101}, payload: %{value: 76}} | _] =
             Agent.get(write_sink, & &1)
  end

  test "timeout fallback rendering and post-timeout promotion are deterministic in test harness",
       %{
         opts: opts
       } do
    # @ac "AC-008"
    harness = LiveViewHarnessAdapter.new(opts)

    {h1, _actions} =
      LiveViewHarnessAdapter.request_scope(
        harness,
        %{container_type: :container, container_id: 5201},
        %{required: [:progress, :objectives], optional: []}
      )

    {h2, _actions} =
      LiveViewHarnessAdapter.request_scope(
        h1,
        %{container_type: :container, container_id: 5202},
        %{required: [:assessments], optional: []}
      )

    {h3, timeout_actions} = LiveViewHarnessAdapter.timeout(h2, 1)

    assert Enum.map(timeout_actions, & &1.type) == [
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

    assert Enum.any?(h3.applied, fn
             %{type: :emit_timeout_fallback, request_token: 1} -> true
             _ -> false
           end)

    assert h3.active_token == 2
    assert h3.loading == [:assessments]
    assert Map.has_key?(h3.timers, 2)
    refute Map.has_key?(h3.timers, 1)
  end
end

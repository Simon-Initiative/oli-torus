defmodule Oli.Dashboard.LiveDataCoordinator.ObservabilityTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.LiveDataCoordinator.Telemetry

  @request_started_event [:oli, :dashboard, :coordinator, :request, :started]
  @request_queued_event [:oli, :dashboard, :coordinator, :request, :queued]
  @request_queue_replaced_event [:oli, :dashboard, :coordinator, :request, :queue_replaced]
  @request_stale_discarded_event [:oli, :dashboard, :coordinator, :request, :stale_discarded]
  @request_timeout_event [:oli, :dashboard, :coordinator, :request, :timeout]
  @cache_consult_event [:oli, :dashboard, :coordinator, :cache, :consult]
  @request_completed_event [:oli, :dashboard, :coordinator, :request, :completed]

  defmodule StubCache do
    def lookup_required(_context, scope, required_oracles, opts) do
      lookup_fun = Keyword.fetch!(opts, :lookup_fun)
      lookup_fun.(scope, required_oracles)
    end

    def write_oracle(_context, _scope, _oracle_key, _payload, _meta, _opts), do: :ok
  end

  setup do
    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 8801,
      user_id: 1001,
      scope: %{container_type: :course}
    }

    lookup_fun = fn _scope, required_oracles ->
      {:ok, %{hits: %{}, misses: required_oracles, source: :none}}
    end

    opts = [
      context: context,
      dashboard_product: :instructor_dashboard,
      cache_module: StubCache,
      cache_opts: [lookup_fun: lookup_fun]
    ]

    %{opts: opts}
  end

  test "emits queue replacement and cache consult telemetry with pii-safe metadata", %{opts: opts} do
    # @ac "AC-006"
    handler = attach_telemetry()

    initial = LiveDataCoordinator.new_session()

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 6101},
        %{required: [:progress], optional: []},
        opts
      )

    {:ok, queued, _actions} =
      LiveDataCoordinator.request_scope_change(
        in_flight,
        %{container_type: :container, container_id: 6102},
        %{required: [:objectives], optional: []},
        opts
      )

    {:ok, _replaced, _actions} =
      LiveDataCoordinator.request_scope_change(
        queued,
        %{container_type: :container, container_id: 6103},
        %{required: [:assessments], optional: []},
        opts
      )

    assert_receive {:telemetry_event, @request_started_event, _m1, started_metadata}
    assert_receive {:telemetry_event, @cache_consult_event, _m2, cache_metadata}
    assert_receive {:telemetry_event, @request_queued_event, _m3, queued_metadata}
    assert_receive {:telemetry_event, @request_queue_replaced_event, _m4, replaced_metadata}

    assert started_metadata.event == :started
    assert cache_metadata.event == :cache_consult
    assert cache_metadata.cache_outcome == :miss
    assert cache_metadata.dashboard_product == :instructor_dashboard
    assert cache_metadata.dashboard_context_type == :section
    assert cache_metadata.scope_container_type == :container
    assert queued_metadata.event == :queued
    assert replaced_metadata.event == :queue_replaced

    assert_pii_safe(started_metadata)
    assert_pii_safe(cache_metadata)
    assert_pii_safe(queued_metadata)
    assert_pii_safe(replaced_metadata)

    :telemetry.detach(handler)
  end

  test "emits stale discard and completion telemetry with normalized timing metadata", %{
    opts: opts
  } do
    # @ac "AC-006"
    handler = attach_telemetry()

    initial = LiveDataCoordinator.new_session()

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 6201},
        %{required: [:progress], optional: []},
        opts
      )

    {:ok, queued, _actions} =
      LiveDataCoordinator.request_scope_change(
        in_flight,
        %{container_type: :container, container_id: 6202},
        %{required: [:objectives], optional: []},
        opts
      )

    {:ok, promoted, _actions} =
      LiveDataCoordinator.handle_oracle_result(
        queued,
        1,
        :progress,
        %{status: :ok, payload: %{value: 72}},
        opts
      )

    {:ok, _next_state, _actions} =
      LiveDataCoordinator.handle_oracle_result(
        promoted,
        1,
        :progress,
        %{status: :ok, payload: %{value: 73}},
        opts
      )

    assert_receive {:telemetry_event, @request_completed_event, completed_measurements,
                    completed_metadata}

    assert completed_measurements.duration_ms >= 0
    assert completed_metadata.completion_outcome == :success
    assert completed_metadata.event == :completed

    assert_receive {:telemetry_event, @request_stale_discarded_event, _m, stale_metadata}
    assert stale_metadata.event == :stale_discarded
    assert stale_metadata.token_state == :stale

    assert_pii_safe(completed_metadata)
    assert_pii_safe(stale_metadata)

    :telemetry.detach(handler)
  end

  test "emits timeout telemetry with deterministic timeout outcome metadata", %{opts: opts} do
    # @ac "AC-006"
    handler = attach_telemetry()

    initial = LiveDataCoordinator.new_session()

    {:ok, in_flight, _actions} =
      LiveDataCoordinator.request_scope_change(
        initial,
        %{container_type: :container, container_id: 6301},
        %{required: [:progress, :objectives], optional: []},
        opts
      )

    {:ok, _state, _actions} = LiveDataCoordinator.handle_request_timeout(in_flight, 1, opts)

    assert_receive {:telemetry_event, @request_timeout_event, timeout_measurements,
                    timeout_metadata}

    assert timeout_measurements.duration_ms >= 0
    assert timeout_metadata.event == :timeout
    assert timeout_metadata.completion_outcome == :timeout
    assert timeout_metadata.dashboard_context_type == :section
    assert timeout_metadata.scope_container_type == :container
    assert_pii_safe(timeout_metadata)

    :telemetry.detach(handler)
  end

  test "metadata sanitizer drops forbidden pii fields" do
    schema = Telemetry.metadata_schema()

    sanitized =
      Telemetry.sanitize_metadata(%{
        type: :cache_consulted,
        request_token: 5,
        dashboard_product: :instructor_dashboard,
        context: %{dashboard_context_type: :section},
        scope: %{container_type: :container},
        cache_outcome: :partial_hit,
        misses: [:progress],
        hits: %{progress: %{value: 99}},
        user_id: 1001,
        dashboard_context_id: 42,
        container_id: 7,
        payload: %{sensitive: true}
      })

    for pii_key <- schema.forbidden_pii do
      refute Map.has_key?(sanitized, pii_key)
    end

    assert sanitized.event == :cache_consult
    assert sanitized.cache_outcome == :partial_hit
    assert sanitized.miss_count == 1
    assert sanitized.hit_count == 1
  end

  defp attach_telemetry do
    handler_id = "ldc-observability-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      Telemetry.events(),
      fn event_name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end

  defp assert_pii_safe(metadata) do
    forbidden = Telemetry.metadata_schema().forbidden_pii

    for pii_key <- forbidden do
      refute Map.has_key?(metadata, pii_key)
    end
  end
end

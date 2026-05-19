defmodule Oli.Dashboard.LiveDataCoordinator.Telemetry do
  @moduledoc """
  Telemetry helpers for dashboard live-data coordinator outcomes.

  Emitted metadata is intentionally PII-safe and excludes user/context/container IDs
  and payload content.
  """

  @request_started_event [:oli, :dashboard, :coordinator, :request, :started]
  @request_queued_event [:oli, :dashboard, :coordinator, :request, :queued]
  @request_queue_replaced_event [:oli, :dashboard, :coordinator, :request, :queue_replaced]
  @request_stale_discarded_event [:oli, :dashboard, :coordinator, :request, :stale_discarded]
  @request_timeout_event [:oli, :dashboard, :coordinator, :request, :timeout]
  @cache_consult_event [:oli, :dashboard, :coordinator, :cache, :consult]
  @request_completed_event [:oli, :dashboard, :coordinator, :request, :completed]

  @doc "Returns coordinator telemetry events."
  @spec events() :: [list(atom())]
  def events do
    [
      @request_started_event,
      @request_queued_event,
      @request_queue_replaced_event,
      @request_stale_discarded_event,
      @request_timeout_event,
      @cache_consult_event,
      @request_completed_event
    ]
  end

  @doc "PII schema guardrails for coordinator telemetry metadata."
  @spec metadata_schema() :: map()
  def metadata_schema do
    %{
      required: [:event],
      optional: [
        :request_token,
        :dashboard_product,
        :dashboard_context_type,
        :scope_container_type,
        :token_state,
        :cache_outcome,
        :completion_outcome,
        :miss_count,
        :hit_count,
        :error_type
      ],
      forbidden_pii: [:user_id, :dashboard_context_id, :container_id, :payload, :hits]
    }
  end

  @doc "Emits one coordinator telemetry event mapped from a coordinator action."
  @spec emit_for_action(map()) :: :ok
  def emit_for_action(action) when is_map(action) do
    case event_for_action(action) do
      nil ->
        :ok

      event ->
        :telemetry.execute(event, measurements_for_action(action), sanitize_metadata(action))
    end
  end

  def emit_for_action(_), do: :ok

  @doc "Normalizes coordinator telemetry metadata to a strict PII-safe schema."
  @spec sanitize_metadata(map() | keyword()) :: map()
  def sanitize_metadata(metadata) do
    normalized = normalize_input(metadata)
    context = normalize_context(Map.get(normalized, :context))
    scope = normalize_scope(Map.get(normalized, :scope))

    %{
      event: normalize_event(Map.get(normalized, :type)),
      request_token: normalize_request_token(Map.get(normalized, :request_token)),
      dashboard_product: normalize_dashboard_product(Map.get(normalized, :dashboard_product)),
      dashboard_context_type:
        normalize_dashboard_context_type(Map.get(context, :dashboard_context_type)),
      scope_container_type: normalize_scope_container_type(Map.get(scope, :container_type)),
      token_state: normalize_token_state(Map.get(normalized, :token_state)),
      cache_outcome: normalize_cache_outcome(Map.get(normalized, :cache_outcome)),
      completion_outcome: normalize_completion_outcome(Map.get(normalized, :completion_outcome)),
      miss_count: normalize_non_negative_integer(miss_count(normalized)),
      hit_count: normalize_non_negative_integer(hit_count(normalized)),
      error_type: normalize_error_type(Map.get(normalized, :reason))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp event_for_action(%{type: :request_started}), do: @request_started_event
  defp event_for_action(%{type: :request_queued}), do: @request_queued_event
  defp event_for_action(%{type: :request_queue_replaced}), do: @request_queue_replaced_event
  defp event_for_action(%{type: :stale_result_suppressed}), do: @request_stale_discarded_event
  defp event_for_action(%{type: :request_timed_out}), do: @request_timeout_event
  defp event_for_action(%{type: :cache_consulted}), do: @cache_consult_event
  defp event_for_action(%{type: :request_completed}), do: @request_completed_event
  defp event_for_action(_), do: nil

  defp measurements_for_action(action) do
    duration_ms =
      case Map.get(action, :duration_ms) do
        value when is_integer(value) and value >= 0 -> value
        _ -> 0
      end

    %{count: 1, duration_ms: duration_ms}
  end

  defp normalize_input(value) when is_list(value), do: normalize_input(Map.new(value))
  defp normalize_input(%{} = value), do: value
  defp normalize_input(_), do: %{}

  defp normalize_context(%{} = context), do: context
  defp normalize_context(_), do: %{}

  defp normalize_scope(%{container_type: container_type}), do: %{container_type: container_type}
  defp normalize_scope(_), do: %{}

  defp normalize_event(:request_started), do: :started
  defp normalize_event(:request_queued), do: :queued
  defp normalize_event(:request_queue_replaced), do: :queue_replaced
  defp normalize_event(:stale_result_suppressed), do: :stale_discarded
  defp normalize_event(:request_timed_out), do: :timeout
  defp normalize_event(:cache_consulted), do: :cache_consult
  defp normalize_event(:request_completed), do: :completed
  defp normalize_event(_), do: :unknown

  defp normalize_request_token(value) when is_integer(value) and value > 0, do: value
  defp normalize_request_token(_), do: nil

  defp normalize_dashboard_product(value) when is_atom(value), do: value
  defp normalize_dashboard_product(value) when is_binary(value), do: value
  defp normalize_dashboard_product(nil), do: :unknown
  defp normalize_dashboard_product(_), do: :unknown

  defp normalize_dashboard_context_type(:section), do: :section
  defp normalize_dashboard_context_type(:project), do: :project
  defp normalize_dashboard_context_type(_), do: :unknown

  defp normalize_scope_container_type(:course), do: :course
  defp normalize_scope_container_type(:container), do: :container
  defp normalize_scope_container_type(_), do: :unknown

  defp normalize_token_state(:active), do: :active
  defp normalize_token_state(:queued), do: :queued
  defp normalize_token_state(:stale), do: :stale
  defp normalize_token_state(nil), do: nil
  defp normalize_token_state(_), do: :unknown

  defp normalize_cache_outcome(:full_hit), do: :full_hit
  defp normalize_cache_outcome(:partial_hit), do: :partial_hit
  defp normalize_cache_outcome(:miss), do: :miss
  defp normalize_cache_outcome(:error), do: :error
  defp normalize_cache_outcome(nil), do: nil
  defp normalize_cache_outcome(_), do: :unknown

  defp normalize_completion_outcome(:success), do: :success
  defp normalize_completion_outcome(:timeout), do: :timeout
  defp normalize_completion_outcome(:unknown), do: :unknown
  defp normalize_completion_outcome(nil), do: nil
  defp normalize_completion_outcome(_), do: :unknown

  defp miss_count(%{misses: misses}) when is_list(misses), do: length(misses)
  defp miss_count(_), do: nil

  defp hit_count(%{hits: hits}) when is_map(hits), do: map_size(hits)
  defp hit_count(_), do: nil

  defp normalize_error_type(nil), do: nil
  defp normalize_error_type(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp normalize_error_type(reason) when is_binary(reason), do: reason
  defp normalize_error_type(reason), do: inspect(reason)

  defp normalize_non_negative_integer(value) when is_integer(value) and value >= 0, do: value
  defp normalize_non_negative_integer(_), do: nil
end

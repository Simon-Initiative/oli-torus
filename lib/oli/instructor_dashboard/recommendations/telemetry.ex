defmodule Oli.InstructorDashboard.Recommendations.Telemetry do
  @moduledoc """
  Telemetry helpers for instructor-dashboard recommendation lifecycle events.

  Metadata emitted from this module is intentionally PII-safe and excludes user id,
  section id, container id, prompt content, and recommendation message text.
  """

  @lifecycle_stop_event [:oli, :instructor_dashboard, :recommendation, :lifecycle, :stop]
  @actions [:implicit_read, :implicit_generate, :explicit_regen, :feedback_submit]
  @outcomes [
    :started,
    :reused,
    :generated,
    :no_signal,
    :fallback,
    :expired,
    :accepted,
    :idempotent,
    :rejected,
    :error
  ]
  @container_types [:course, :container]
  @dashboard_context_types [:section, :project]
  @generation_modes [:implicit, :explicit_regen]
  @feedback_types [:thumbs_up, :thumbs_down, :additional_text]
  @rate_limits [:hit, :miss]
  @cache_refresh_statuses [:ok, :partial, :failed, :skipped]

  @type lifecycle_metadata :: %{
          required(:action) =>
            :implicit_read | :implicit_generate | :explicit_regen | :feedback_submit | :unknown,
          required(:outcome) =>
            :reused
            | :started
            | :generated
            | :no_signal
            | :fallback
            | :expired
            | :accepted
            | :idempotent
            | :rejected
            | :error
            | :unknown,
          required(:container_type) => :course | :container | :unknown,
          optional(:dashboard_context_type) => :section | :project | :unknown,
          optional(:generation_mode) => :implicit | :explicit_regen,
          optional(:feedback_type) => :thumbs_up | :thumbs_down | :additional_text,
          optional(:rate_limit) => :hit | :miss,
          optional(:fallback_reason) => atom() | String.t(),
          optional(:cache_refresh) => :ok | :partial | :failed | :skipped | :unknown,
          optional(:error_type) => String.t()
        }

  @spec events() :: [list(atom())]
  def events, do: [@lifecycle_stop_event]

  @spec lifecycle_stop(map(), map() | keyword()) :: :ok
  def lifecycle_stop(measurements, metadata) do
    :telemetry.execute(
      @lifecycle_stop_event,
      normalize_measurements(measurements),
      sanitize_lifecycle_metadata(metadata)
    )
  end

  @spec sanitize_lifecycle_metadata(map() | keyword()) :: lifecycle_metadata()
  def sanitize_lifecycle_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      action: normalize_action(Map.get(normalized, :action)),
      outcome: normalize_outcome(Map.get(normalized, :outcome)),
      container_type: normalize_container_type(Map.get(normalized, :container_type)),
      dashboard_context_type:
        normalize_dashboard_context_type(Map.get(normalized, :dashboard_context_type)),
      generation_mode: normalize_generation_mode(Map.get(normalized, :generation_mode)),
      feedback_type: normalize_feedback_type(Map.get(normalized, :feedback_type)),
      rate_limit: normalize_rate_limit(Map.get(normalized, :rate_limit)),
      fallback_reason: normalize_reason(Map.get(normalized, :fallback_reason)),
      cache_refresh: normalize_cache_refresh(Map.get(normalized, :cache_refresh)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_measurements(%{} = measurements) do
    duration_ms =
      case Map.get(measurements, :duration_ms) do
        value when is_integer(value) and value >= 0 -> value
        _ -> 0
      end

    %{count: 1, duration_ms: duration_ms}
  end

  defp normalize_measurements(_), do: %{count: 1, duration_ms: 0}

  defp normalize_input_metadata(metadata) when is_list(metadata),
    do: normalize_input_metadata(Map.new(metadata))

  defp normalize_input_metadata(%{} = metadata), do: metadata
  defp normalize_input_metadata(_), do: %{}

  defp normalize_action(value) when value in @actions, do: value
  defp normalize_action(_), do: :unknown

  defp normalize_outcome(value) when value in @outcomes, do: value
  defp normalize_outcome(_), do: :unknown

  defp normalize_container_type(value) when value in @container_types, do: value
  defp normalize_container_type(_), do: :unknown

  defp normalize_dashboard_context_type(value) when value in @dashboard_context_types, do: value
  defp normalize_dashboard_context_type(nil), do: nil
  defp normalize_dashboard_context_type(_), do: :unknown

  defp normalize_generation_mode(value) when value in @generation_modes, do: value
  defp normalize_generation_mode(nil), do: nil
  defp normalize_generation_mode(_), do: nil

  defp normalize_feedback_type(value) when value in @feedback_types, do: value
  defp normalize_feedback_type(nil), do: nil
  defp normalize_feedback_type(_), do: nil

  defp normalize_rate_limit(value) when value in @rate_limits, do: value
  defp normalize_rate_limit(nil), do: nil
  defp normalize_rate_limit(_), do: nil

  defp normalize_reason(nil), do: nil
  defp normalize_reason(value) when is_atom(value), do: value
  defp normalize_reason(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp normalize_reason(_), do: nil

  defp normalize_cache_refresh(value) when value in @cache_refresh_statuses, do: value
  defp normalize_cache_refresh(nil), do: nil
  defp normalize_cache_refresh(_), do: :unknown

  defp normalize_error_type(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_error_type(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp normalize_error_type(_), do: nil
end

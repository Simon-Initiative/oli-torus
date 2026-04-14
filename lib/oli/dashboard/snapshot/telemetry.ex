defmodule Oli.Dashboard.Snapshot.Telemetry do
  @moduledoc """
  Telemetry helpers for snapshot assembly and projection derivation.

  Metadata emitted by this module is intentionally PII-safe and excludes user id,
  dashboard context id, container id, and payload content.
  """

  @assembly_stop_event [:oli, :dashboard, :snapshot, :assembly, :stop]
  @projection_stop_event [:oli, :dashboard, :snapshot, :projection, :stop]
  @projection_status_event [:oli, :dashboard, :snapshot, :projection, :status]
  @export_stop_event [:oli, :dashboard, :snapshot, :export, :stop]

  @type snapshot_metadata :: %{
          required(:outcome) => :ok | :error | :unknown,
          required(:container_type) => :course | :container | :unknown,
          optional(:oracle_count) => non_neg_integer(),
          optional(:status_count) => non_neg_integer(),
          optional(:error_type) => String.t()
        }

  @type projection_metadata :: %{
          required(:capability_key) => atom() | String.t(),
          required(:status) => :ready | :partial | :failed | :unavailable | :unknown,
          required(:outcome) => :ok | :error | :unknown,
          optional(:reason_code) => atom() | String.t(),
          optional(:error_type) => String.t(),
          optional(:oracle_count) => non_neg_integer()
        }

  @type export_metadata :: %{
          required(:outcome) => :ok | :error | :unknown,
          required(:scope_container_type) => :course | :container | :unknown,
          required(:export_profile) => atom() | String.t(),
          optional(:dataset_count) => non_neg_integer(),
          optional(:included_count) => non_neg_integer(),
          optional(:excluded_count) => non_neg_integer(),
          optional(:reason_code) => atom() | String.t(),
          optional(:error_type) => String.t()
        }

  @spec events() :: [list(atom())]
  def events do
    [
      @assembly_stop_event,
      @projection_stop_event,
      @projection_status_event,
      @export_stop_event
    ]
  end

  @spec assembly_stop(map(), map() | keyword()) :: :ok
  def assembly_stop(measurements, metadata) do
    :telemetry.execute(
      @assembly_stop_event,
      normalize_measurements(measurements),
      sanitize_assembly_metadata(metadata)
    )
  end

  @spec projection_stop(map(), map() | keyword()) :: :ok
  def projection_stop(measurements, metadata) do
    :telemetry.execute(
      @projection_stop_event,
      normalize_measurements(measurements),
      sanitize_projection_metadata(metadata)
    )
  end

  @spec projection_status(map() | keyword()) :: :ok
  def projection_status(metadata) do
    :telemetry.execute(
      @projection_status_event,
      %{count: 1},
      sanitize_projection_metadata(metadata)
    )
  end

  @spec export_stop(map(), map() | keyword()) :: :ok
  def export_stop(measurements, metadata) do
    :telemetry.execute(
      @export_stop_event,
      normalize_measurements(measurements),
      sanitize_export_metadata(metadata)
    )
  end

  @spec sanitize_assembly_metadata(map() | keyword()) :: snapshot_metadata()
  def sanitize_assembly_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      outcome: normalize_outcome(Map.get(normalized, :outcome)),
      container_type: normalize_container_type(Map.get(normalized, :container_type)),
      oracle_count: normalize_non_negative_integer(Map.get(normalized, :oracle_count)),
      status_count: normalize_non_negative_integer(Map.get(normalized, :status_count)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> drop_nil_values()
  end

  @spec sanitize_projection_metadata(map() | keyword()) :: projection_metadata()
  def sanitize_projection_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      capability_key: normalize_capability_key(Map.get(normalized, :capability_key)),
      status: normalize_projection_status(Map.get(normalized, :status)),
      outcome: normalize_outcome(Map.get(normalized, :outcome)),
      reason_code: normalize_reason_code(Map.get(normalized, :reason_code)),
      error_type: normalize_error_type(Map.get(normalized, :error_type)),
      oracle_count: normalize_non_negative_integer(Map.get(normalized, :oracle_count))
    }
    |> drop_nil_values()
  end

  @spec sanitize_export_metadata(map() | keyword()) :: export_metadata()
  def sanitize_export_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      outcome: normalize_outcome(Map.get(normalized, :outcome)),
      scope_container_type: normalize_container_type(Map.get(normalized, :scope_container_type)),
      export_profile: normalize_export_profile(Map.get(normalized, :export_profile)),
      dataset_count: normalize_non_negative_integer(Map.get(normalized, :dataset_count)),
      included_count: normalize_non_negative_integer(Map.get(normalized, :included_count)),
      excluded_count: normalize_non_negative_integer(Map.get(normalized, :excluded_count)),
      reason_code: normalize_reason_code(Map.get(normalized, :reason_code)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> drop_nil_values()
  end

  defp normalize_measurements(%{} = measurements) do
    case Map.get(measurements, :duration_ms) do
      duration_ms when is_integer(duration_ms) and duration_ms >= 0 -> %{duration_ms: duration_ms}
      _ -> %{duration_ms: 0}
    end
  end

  defp normalize_measurements(_), do: %{duration_ms: 0}

  defp normalize_input_metadata(metadata) when is_list(metadata),
    do: normalize_input_metadata(Map.new(metadata))

  defp normalize_input_metadata(%{} = metadata), do: metadata
  defp normalize_input_metadata(_), do: %{}

  defp normalize_outcome(:ok), do: :ok
  defp normalize_outcome(:error), do: :error
  defp normalize_outcome(_), do: :unknown

  defp normalize_projection_status(:ready), do: :ready
  defp normalize_projection_status(:partial), do: :partial
  defp normalize_projection_status(:failed), do: :failed
  defp normalize_projection_status(:unavailable), do: :unavailable
  defp normalize_projection_status(_), do: :unknown

  defp normalize_container_type(:course), do: :course
  defp normalize_container_type(:container), do: :container
  defp normalize_container_type(_), do: :unknown

  defp normalize_export_profile(value) when is_atom(value), do: value
  defp normalize_export_profile(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp normalize_export_profile(_), do: "unknown"

  defp normalize_capability_key(value) when is_atom(value), do: value
  defp normalize_capability_key(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp normalize_capability_key(_), do: "unknown"

  defp normalize_reason_code(value) when is_atom(value), do: value
  defp normalize_reason_code(value) when is_binary(value), do: value
  defp normalize_reason_code(_), do: nil

  defp normalize_error_type(value) when is_binary(value), do: value
  defp normalize_error_type(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_error_type(nil), do: nil
  defp normalize_error_type(other), do: inspect(other)

  defp normalize_non_negative_integer(value) when is_integer(value) and value >= 0, do: value
  defp normalize_non_negative_integer(_), do: nil

  defp drop_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end

defmodule Oli.Dashboard.OracleTelemetry do
  @moduledoc """
  Telemetry helpers and AppSignal metric wiring for dashboard oracle contracts.
  """

  use Supervisor

  @resolve_stop_event [:oli, :dashboard, :oracles, :registry, :resolve, :stop]
  @lookup_stop_event [:oli, :dashboard, :oracles, :registry, :lookup, :stop]
  @validation_error_event [:oli, :dashboard, :oracles, :registry, :validation, :error]
  @contract_error_event [:oli, :dashboard, :oracles, :contract, :error]

  @doc "Starts telemetry handler supervisor and attaches AppSignal handlers."
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @spec events() :: [list(atom())]
  def events do
    [@resolve_stop_event, @lookup_stop_event, @validation_error_event, @contract_error_event]
  end

  @doc "Emits registry dependency resolution stop telemetry event."
  def registry_resolve_stop(measurements, metadata) do
    :telemetry.execute(
      @resolve_stop_event,
      normalize_measurements(measurements),
      sanitize_metadata(metadata)
    )
  end

  @doc "Emits registry oracle lookup stop telemetry event."
  def registry_lookup_stop(measurements, metadata) do
    :telemetry.execute(
      @lookup_stop_event,
      normalize_measurements(measurements),
      sanitize_metadata(metadata)
    )
  end

  @doc "Emits registry validation error telemetry event."
  def registry_validation_error(metadata) do
    :telemetry.execute(@validation_error_event, %{count: 1}, sanitize_metadata(metadata))
  end

  @doc "Emits oracle contract error telemetry event."
  def contract_error(metadata) do
    :telemetry.execute(@contract_error_event, %{count: 1}, sanitize_metadata(metadata))
  end

  @doc "AppSignal mapping for dashboard oracle telemetry."
  def handle_event(@resolve_stop_event, measurements, metadata, _config) do
    duration_ms = Map.get(measurements, :duration_ms, 0)
    tags = metric_tags(metadata)

    Appsignal.add_distribution_value(
      "oli.dashboard.oracles.registry.resolve.duration_ms",
      duration_ms,
      tags
    )

    Appsignal.increment_counter("oli.dashboard.oracles.registry.resolve", 1, tags)
    maybe_increment_registry_error(tags)
  end

  def handle_event(@lookup_stop_event, measurements, metadata, _config) do
    duration_ms = Map.get(measurements, :duration_ms, 0)
    tags = metric_tags(metadata)

    Appsignal.add_distribution_value(
      "oli.dashboard.oracles.registry.lookup.duration_ms",
      duration_ms,
      tags
    )

    Appsignal.increment_counter("oli.dashboard.oracles.registry.lookup", 1, tags)
    maybe_increment_registry_error(tags)
  end

  def handle_event(@validation_error_event, _measurements, metadata, _config) do
    tags = metric_tags(metadata)
    Appsignal.increment_counter("oli.dashboard.oracles.registry.error", 1, tags)
  end

  def handle_event(@contract_error_event, _measurements, metadata, _config) do
    tags = metric_tags(metadata)
    Appsignal.increment_counter("oli.dashboard.oracles.contract.error", 1, tags)
  end

  def handle_event(_, _, _, _), do: :ok

  defp maybe_increment_registry_error(%{outcome: "ok"}), do: :ok

  defp maybe_increment_registry_error(tags) do
    Appsignal.increment_counter("oli.dashboard.oracles.registry.error", 1, tags)
  end

  defp metric_tags(metadata) do
    %{
      dashboard_product: normalize(metadata[:dashboard_product]),
      consumer_key: normalize(metadata[:consumer_key]),
      oracle_key: normalize(metadata[:oracle_key]),
      outcome: normalize(metadata[:outcome]),
      error_type: normalize(metadata[:error_type]),
      event: normalize(metadata[:event])
    }
  end

  defp normalize_measurements(measurements) when is_map(measurements) do
    case Map.get(measurements, :duration_ms) do
      duration_ms when is_integer(duration_ms) and duration_ms >= 0 -> %{duration_ms: duration_ms}
      _ -> %{duration_ms: 0}
    end
  end

  defp normalize_measurements(_), do: %{duration_ms: 0}

  defp sanitize_metadata(metadata) when is_list(metadata),
    do: sanitize_metadata(Map.new(metadata))

  defp sanitize_metadata(metadata) when is_map(metadata) do
    %{
      dashboard_product: normalize_dashboard_product(metadata[:dashboard_product]),
      consumer_key: normalize_key(metadata[:consumer_key]),
      oracle_key: normalize_key(metadata[:oracle_key]),
      outcome: normalize_outcome(metadata[:outcome]),
      error_type: normalize(metadata[:error_type]),
      event: normalize(metadata[:event])
    }
  end

  defp sanitize_metadata(_),
    do: %{
      dashboard_product: :unknown,
      consumer_key: nil,
      oracle_key: nil,
      outcome: :unknown,
      error_type: "unknown",
      event: "unknown"
    }

  defp normalize_dashboard_product(value) when is_atom(value), do: value
  defp normalize_dashboard_product(value) when is_binary(value), do: value
  defp normalize_dashboard_product(_), do: :unknown

  defp normalize_key(value) when is_atom(value), do: value
  defp normalize_key(value) when is_binary(value), do: value
  defp normalize_key(_), do: nil

  defp normalize_outcome(value) when is_atom(value), do: value
  defp normalize_outcome(value) when is_binary(value), do: value
  defp normalize_outcome(_), do: :unknown

  defp normalize(nil), do: "unknown"
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value) when is_binary(value), do: value
  defp normalize(value), do: to_string(value)

  defp attach_appsignal_handler do
    handler_id = "dashboard-oracle-appsignal-handler"

    case :telemetry.attach_many(handler_id, events(), &__MODULE__.handle_event/4, %{}) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end

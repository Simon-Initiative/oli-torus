defmodule Oli.GenAI.Telemetry do
  @moduledoc """
  GenAI telemetry helpers and AppSignal metric wiring.
  """

  use Supervisor

  @router_decision_event [:oli, :genai, :router, :decision]
  @router_admission_event [:oli, :genai, :router, :admission]
  @provider_stop_event [:oli, :genai, :provider, :stop]
  @breaker_state_change_event [:oli, :genai, :breaker, :state_change]

  @doc "Starts the telemetry supervisor and attaches AppSignal handlers."
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  @doc "Supervisor init callback; attaches AppSignal handlers."
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc "Emits a routing decision telemetry event."
  def router_decision(measurements, metadata) do
    :telemetry.execute(@router_decision_event, measurements, metadata)
  end

  @doc "Emits a routing admission telemetry event."
  def router_admission(measurements, metadata) do
    :telemetry.execute(@router_admission_event, measurements, metadata)
  end

  @doc "Emits a provider stop telemetry event."
  def provider_stop(measurements, metadata) do
    :telemetry.execute(@provider_stop_event, measurements, metadata)
  end

  @doc "Emits a breaker state change telemetry event."
  def breaker_state_change(measurements, metadata) do
    :telemetry.execute(@breaker_state_change_event, measurements, metadata)
  end

  @doc "Telemetry handler that maps GenAI events to AppSignal metrics."
  def handle_event(@router_decision_event, measurements, metadata, _config) do
    duration_ms = Map.get(measurements, :duration_ms, 0)
    reason = normalize(metadata[:reason])
    request_type = normalize(metadata[:request_type])
    tier = normalize(metadata[:tier])
    pool_class = normalize(metadata[:pool_class])

    tags = %{reason: reason, request_type: request_type, tier: tier, pool_class: pool_class}

    Appsignal.add_distribution_value("oli.genai.router.duration_ms", duration_ms, tags)
    Appsignal.increment_counter("oli.genai.router.decision", 1, tags)

    if rejection_reason?(metadata[:reason]) do
      Appsignal.increment_counter("oli.genai.router.rejection", 1, tags)
    end
  end

  def handle_event(@router_admission_event, measurements, metadata, _config) do
    admitted = Map.get(measurements, :admitted, 0)
    request_type = normalize(metadata[:request_type])
    tier = normalize(metadata[:tier])
    pool_class = normalize(metadata[:pool_class])

    tags = %{
      admitted: if(admitted == 1, do: "true", else: "false"),
      request_type: request_type,
      tier: tier,
      pool_class: pool_class
    }

    Appsignal.increment_counter("oli.genai.router.admission", 1, tags)
  end

  def handle_event(@provider_stop_event, measurements, metadata, _config) do
    duration_ms = Map.get(measurements, :duration_ms, 0)

    tags = %{
      provider: normalize(metadata[:provider]),
      model: normalize(metadata[:model]),
      outcome: normalize(metadata[:outcome]),
      request_type: normalize(metadata[:request_type])
    }

    Appsignal.add_distribution_value("oli.genai.provider.duration_ms", duration_ms, tags)
    Appsignal.increment_counter("oli.genai.provider.call", 1, tags)

    if metadata[:outcome] == :error do
      Appsignal.increment_counter("oli.genai.provider.error", 1, tags)
    end
  end

  def handle_event(@breaker_state_change_event, _measurements, metadata, _config) do
    state = normalize(metadata[:state])
    reason = normalize(metadata[:reason])
    tags = %{state: state, reason: reason}

    Appsignal.increment_counter("oli.genai.breaker.state_change", 1, tags)

    if metadata[:state] == :open do
      Appsignal.increment_counter("oli.genai.breaker.open", 1, tags)
    end
  end

  def handle_event(_, _, _, _), do: :ok

  defp attach_appsignal_handler do
    handler_id = "genai-appsignal-handler"

    case :telemetry.attach_many(
           handler_id,
           [
             @router_decision_event,
             @router_admission_event,
             @provider_stop_event,
             @breaker_state_change_event
           ],
           &__MODULE__.handle_event/4,
           %{}
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  defp normalize(nil), do: "unknown"
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value) when is_binary(value), do: value
  defp normalize(value), do: to_string(value)

  defp rejection_reason?(reason) do
    reason in [
      :over_capacity,
      :primary_over_capacity,
      :secondary_over_capacity,
      :secondary_unavailable,
      :secondary_breaker_open,
      :backup_breaker_open,
      :all_breakers_open,
      :invalid_limit
    ]
  end
end

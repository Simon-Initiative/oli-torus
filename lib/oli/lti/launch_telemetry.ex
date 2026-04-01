defmodule Oli.Lti.LaunchTelemetry do
  @moduledoc """
  Privacy-safe telemetry for LTI launch flow selection and outcomes.
  """

  @start_event [:torus, :lti, :launch, :start]
  @validated_event [:torus, :lti, :launch, :validated]
  @recovery_event [:torus, :lti, :launch, :recovery]
  @failure_event [:torus, :lti, :launch, :failure]

  def emit_start(metadata), do: emit(@start_event, %{count: 1}, metadata)
  def emit_validated(metadata), do: emit(@validated_event, %{count: 1}, metadata)
  def emit_recovery(metadata), do: emit(@recovery_event, %{count: 1}, metadata)
  def emit_failure(metadata), do: emit(@failure_event, %{count: 1}, metadata)

  defp emit(event, measurements, metadata) do
    metadata = sanitize(metadata)
    :telemetry.execute(event, measurements, metadata)
    emit_appsignal(event, metadata)
  end

  defp sanitize(metadata) do
    metadata
    |> Map.take([
      :classification,
      :client_id,
      :deployment_id,
      :embedded_context,
      :flow_mode,
      :issuer,
      :message_type,
      :request_id,
      :storage_supported
    ])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp emit_appsignal(event, metadata) do
    tags =
      metadata
      |> Map.take([:classification, :flow_mode, :request_id, :storage_supported])
      |> Enum.into(%{}, fn {key, value} -> {key, to_string(value)} end)

    Appsignal.increment_counter(metric_name(event), 1, tags)
  end

  defp metric_name(@start_event), do: "torus.lti.launch.start"
  defp metric_name(@validated_event), do: "torus.lti.launch.validated"
  defp metric_name(@recovery_event), do: "torus.lti.launch.recovery"
  defp metric_name(@failure_event), do: "torus.lti.launch.failure"
end

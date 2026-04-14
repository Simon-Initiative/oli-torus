defmodule Oli.Dashboard.Snapshot.Projections do
  @moduledoc """
  Capability projection derivation over assembled snapshot contracts.

  Projection derivation is capability-scoped. Failures in one capability must
  not block derivation for unrelated capabilities.
  """

  require Logger

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Telemetry
  alias Oli.InstructorDashboard.DataSnapshot.Projections, as: InstructorProjections

  @type capability_key :: atom() | String.t()
  @type projection :: map()
  @type projection_status :: Contract.projection_status()
  @type projection_modules :: %{optional(capability_key()) => module()}
  @type error :: {:projection_failed, term()}

  @spec derive_all(Contract.t(), keyword()) ::
          {:ok, %{projections: map(), statuses: map()}} | {:error, error()}
  def derive_all(snapshot, opts \\ [])

  def derive_all(%Contract{} = snapshot, opts) do
    modules = projection_modules(opts)

    {projections, statuses} =
      Enum.reduce(modules, {%{}, %{}}, fn {capability_key, module},
                                          {projection_acc, status_acc} ->
        {projection, status} = derive_capability(capability_key, module, snapshot, opts)

        {put_projection(projection_acc, capability_key, projection),
         Map.put(status_acc, capability_key, status)}
      end)

    {:ok, %{projections: projections, statuses: statuses}}
  end

  def derive_all(_snapshot, _opts), do: {:error, {:projection_failed, :invalid_snapshot}}

  @spec derive(capability_key(), Contract.t(), keyword()) ::
          {:ok, projection(), projection_status()} | {:error, error()}
  def derive(capability_key, snapshot, opts \\ [])

  def derive(capability_key, %Contract{} = snapshot, opts) do
    modules = projection_modules(opts)

    case Map.fetch(modules, capability_key) do
      {:ok, module} ->
        {projection, status} = derive_capability(capability_key, module, snapshot, opts)
        {:ok, projection, status}

      :error ->
        {:error, {:projection_failed, {:unknown_capability, capability_key}}}
    end
  end

  def derive(_capability_key, _snapshot, _opts),
    do: {:error, {:projection_failed, :invalid_snapshot}}

  defp derive_capability(capability_key, module, snapshot, opts) do
    started_at = System.monotonic_time()

    result =
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          if function_exported?(module, :derive, 2) do
            module.derive(snapshot, opts)
          else
            {:error, {:invalid_projection_module, module}}
          end

        {:error, reason} ->
          {:error, {:projection_module_not_loaded, module, reason}}
      end

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    oracle_count = map_size(snapshot.oracles)

    case result do
      {:ok, projection} ->
        status = %{status: :ready}
        emit_projection_telemetry(capability_key, status, :ok, duration_ms, oracle_count)
        Logger.debug("projection ready capability=#{inspect(capability_key)}")
        {projection, status}

      {:partial, projection, reason} ->
        reason_code = Contract.projection_reason_code(reason)
        status = %{status: :partial, reason: reason, reason_code: reason_code}
        emit_projection_telemetry(capability_key, status, :ok, duration_ms, oracle_count)

        Logger.warning(
          "projection partial capability=#{inspect(capability_key)} reason=#{inspect(reason)}"
        )

        {projection, status}

      {:unavailable, reason} ->
        status = %{
          status: :unavailable,
          reason: reason,
          reason_code: Contract.projection_reason_code(reason)
        }

        emit_projection_telemetry(capability_key, status, :ok, duration_ms, oracle_count)

        Logger.warning(
          "projection unavailable capability=#{inspect(capability_key)} reason=#{inspect(reason)}"
        )

        {%{}, status}

      {:error, reason} ->
        reason_code = Contract.projection_reason_code(reason)
        status = %{status: :failed, reason: reason, reason_code: reason_code}
        emit_projection_telemetry(capability_key, status, :error, duration_ms, oracle_count)

        Logger.error(
          "projection failed capability=#{inspect(capability_key)} reason=#{inspect(reason)}"
        )

        {%{}, status}

      other ->
        reason = {:invalid_projection_return, capability_key, other}
        status = %{status: :failed, reason: reason, reason_code: :projection_derivation_failed}
        emit_projection_telemetry(capability_key, status, :error, duration_ms, oracle_count)
        Logger.error("projection invalid return capability=#{inspect(capability_key)}")
        {%{}, status}
    end
  end

  defp projection_modules(opts) do
    Keyword.get(opts, :projection_modules, InstructorProjections.modules())
  end

  defp put_projection(acc, _capability_key, projection) when projection == %{}, do: acc

  defp put_projection(acc, capability_key, projection),
    do: Map.put(acc, capability_key, projection)

  defp emit_projection_telemetry(capability_key, status, outcome, duration_ms, oracle_count) do
    metadata = %{
      capability_key: capability_key,
      status: status.status,
      outcome: outcome,
      reason_code: status[:reason_code],
      error_type: error_type(status[:reason]),
      oracle_count: oracle_count
    }

    Telemetry.projection_stop(%{duration_ms: duration_ms}, metadata)
    Telemetry.projection_status(metadata)
  end

  defp error_type(nil), do: nil
  defp error_type({type, _}) when is_atom(type), do: Atom.to_string(type)
  defp error_type(type) when is_atom(type), do: Atom.to_string(type)
  defp error_type(other), do: inspect(other)
end

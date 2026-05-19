defmodule Oli.Dashboard.Snapshot.Assembler do
  @moduledoc """
  Canonical snapshot assembler over oracle result envelopes.

  This module is queryless and policy-agnostic. It composes contract data from
  externally supplied oracle results.
  """

  require Logger

  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Telemetry

  @type context_input :: OracleContext.input()
  @type request_token :: String.t()
  @type oracle_key :: atom() | String.t()
  @type oracle_result :: map()
  @type oracle_results :: %{optional(oracle_key()) => oracle_result()} | [oracle_result()]
  @type opts :: keyword()
  @type error :: {:snapshot_assembly_failed, term()}

  @spec assemble(context_input(), request_token(), oracle_results(), opts()) ::
          {:ok, Contract.t()} | {:error, error()}
  def assemble(context_input, request_token, oracle_results, opts \\ []) do
    started_at = System.monotonic_time()

    Logger.debug("snapshot assemble started")

    result =
      with {:ok, context} <- OracleContext.new(context_input),
           {:ok, merged_results} <- merge_oracle_results(%{}, oracle_results),
           {:ok, expected_oracles} <- normalize_expected_oracles(opts),
           {oracle_payloads, oracle_statuses} <-
             build_oracle_maps(merged_results, expected_oracles),
           {:ok, snapshot_input} <-
             build_snapshot_input(
               context,
               request_token,
               oracle_payloads,
               oracle_statuses,
               opts
             ),
           {:ok, snapshot} <- Contract.new_snapshot(snapshot_input) do
        {:ok, snapshot}
      else
        {:error, reason} -> {:error, {:snapshot_assembly_failed, reason}}
      end

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    emit_assembly_telemetry(result, duration_ms)
    log_assembly_result(result)

    result
  end

  @doc """
  Deterministically merges oracle results by oracle key.

  Incoming results override existing results for the same key.
  """
  @spec merge_oracle_results(oracle_results(), oracle_results()) ::
          {:ok, %{optional(oracle_key()) => oracle_result()}} | {:error, term()}
  def merge_oracle_results(existing_results, incoming_results) do
    with {:ok, existing_map} <- normalize_oracle_results(existing_results),
         {:ok, incoming_map} <- normalize_oracle_results(incoming_results) do
      {:ok, Map.merge(existing_map, incoming_map)}
    end
  end

  defp normalize_oracle_results(nil), do: {:ok, %{}}

  defp normalize_oracle_results(results) when is_list(results) do
    Enum.reduce_while(results, {:ok, %{}}, fn result, {:ok, acc} ->
      case normalize_single_result(result) do
        {:ok, key, normalized} -> {:cont, {:ok, Map.put(acc, key, normalized)}}
        {:error, reason} -> {:halt, {:error, {:invalid_oracle_result, reason}}}
      end
    end)
  end

  defp normalize_oracle_results(results) when is_map(results) do
    Enum.reduce_while(results, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case normalize_single_result(Map.put(normalize_map(value), :oracle_key, key)) do
        {:ok, normalized_key, normalized} ->
          {:cont, {:ok, Map.put(acc, normalized_key, normalized)}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_oracle_result, reason}}}
      end
    end)
  end

  defp normalize_oracle_results(other), do: {:error, {:invalid_oracle_results, other}}

  defp normalize_single_result(%{} = result) do
    key = Map.get(result, :oracle_key) || Map.get(result, "oracle_key")
    status = Map.get(result, :status) || Map.get(result, "status")

    with {:ok, oracle_key} <- normalize_oracle_key(key),
         {:ok, normalized_status} <- normalize_oracle_status(status),
         {:ok, stale?} <- normalize_stale(Map.get(result, :stale?) || Map.get(result, "stale?")),
         {:ok, oracle_version} <- normalize_oracle_version(result),
         metadata <- normalize_oracle_metadata(result),
         normalized <-
           normalize_oracle_result_payload(normalized_status, result, oracle_key, oracle_version) do
      {:ok, oracle_key,
       Map.merge(
         %{
           status: normalized_status,
           stale?: stale?,
           oracle_version: oracle_version,
           metadata: metadata
         },
         normalized
       )}
    end
  end

  defp normalize_single_result(other), do: {:error, {:invalid_result_shape, other}}

  defp normalize_oracle_result_payload(:ok, result, _oracle_key, _oracle_version) do
    payload = Map.get(result, :payload) || Map.get(result, "payload")
    %{payload: payload}
  end

  defp normalize_oracle_result_payload(:error, result, _oracle_key, _oracle_version) do
    %{reason: Map.get(result, :reason) || Map.get(result, "reason")}
  end

  defp normalize_oracle_key(value) when is_atom(value), do: {:ok, value}

  defp normalize_oracle_key(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_oracle_key(other), do: {:error, {:invalid_oracle_key, other}}

  defp normalize_oracle_status(:ok), do: {:ok, :ok}
  defp normalize_oracle_status(:error), do: {:ok, :error}
  defp normalize_oracle_status("ok"), do: {:ok, :ok}
  defp normalize_oracle_status("error"), do: {:ok, :error}
  defp normalize_oracle_status(other), do: {:error, {:invalid_oracle_status, other}}

  defp normalize_stale(nil), do: {:ok, false}
  defp normalize_stale(value) when is_boolean(value), do: {:ok, value}
  defp normalize_stale(other), do: {:error, {:invalid_stale_flag, other}}

  defp normalize_oracle_version(result) do
    case Map.get(result, :oracle_version) || Map.get(result, "oracle_version") do
      version when is_integer(version) and version >= 0 ->
        {:ok, version}

      _ ->
        {:ok, 0}
    end
  end

  defp normalize_oracle_metadata(result) do
    Map.get(result, :metadata) || Map.get(result, "metadata") || %{}
  end

  defp normalize_expected_oracles(opts) do
    expected_oracles = Keyword.get(opts, :expected_oracles, [])

    Enum.reduce_while(expected_oracles, {:ok, []}, fn key, {:ok, acc} ->
      case normalize_oracle_key(key) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, keys} -> {:ok, keys |> Enum.reverse() |> Enum.uniq()}
      error -> error
    end
  end

  defp build_oracle_maps(merged_results, expected_oracles) do
    {oracle_payloads, oracle_statuses} =
      Enum.reduce(merged_results, {%{}, %{}}, fn {oracle_key, envelope}, {payloads, statuses} ->
        {next_payloads, next_statuses} =
          put_oracle_entry(payloads, statuses, oracle_key, envelope)

        {next_payloads, next_statuses}
      end)

    add_unavailable_expected_oracles(oracle_payloads, oracle_statuses, expected_oracles)
  end

  defp put_oracle_entry(payloads, statuses, oracle_key, %{status: :ok} = envelope) do
    payload = Map.get(envelope, :payload)

    {
      Map.put(payloads, oracle_key, payload),
      Map.put(statuses, oracle_key, %{
        status: :ready,
        stale?: Map.get(envelope, :stale?, false),
        oracle_version: Map.get(envelope, :oracle_version, 0),
        metadata: Map.get(envelope, :metadata, %{})
      })
    }
  end

  defp put_oracle_entry(payloads, statuses, oracle_key, %{status: :error} = envelope) do
    reason = Map.get(envelope, :reason)

    {
      payloads,
      Map.put(statuses, oracle_key, %{
        status: :failed,
        stale?: Map.get(envelope, :stale?, false),
        oracle_version: Map.get(envelope, :oracle_version, 0),
        metadata: Map.get(envelope, :metadata, %{}),
        reason: reason,
        reason_code: Contract.projection_reason_code(reason)
      })
    }
  end

  defp add_unavailable_expected_oracles(payloads, statuses, expected_oracles) do
    Enum.reduce(expected_oracles, {payloads, statuses}, fn oracle_key,
                                                           {payload_acc, status_acc} ->
      if Map.has_key?(status_acc, oracle_key) do
        {payload_acc, status_acc}
      else
        {
          payload_acc,
          Map.put(status_acc, oracle_key, %{
            status: :unavailable,
            stale?: false,
            oracle_version: 0,
            metadata: %{},
            reason: {:missing_oracle_payload, oracle_key},
            reason_code: :missing_oracle_payload
          })
        }
      end
    end)
  end

  defp build_snapshot_input(context, request_token, oracle_payloads, oracle_statuses, opts) do
    scope = Keyword.get(opts, :scope, context.scope)
    metadata = build_metadata(context, scope, opts)

    {:ok,
     %{
       request_token: request_token,
       context: context,
       scope: scope,
       metadata: metadata,
       snapshot_version:
         Keyword.get(opts, :snapshot_version, Contract.current_snapshot_version()),
       projection_version:
         Keyword.get(opts, :projection_version, Contract.current_projection_version()),
       oracles: oracle_payloads,
       oracle_statuses: oracle_statuses,
       projections: %{},
       projection_statuses: %{}
     }}
  end

  defp build_metadata(context, scope, opts) do
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now())

    custom =
      opts
      |> Keyword.get(:metadata, %{})
      |> normalize_map()

    Map.merge(custom, %{
      dashboard_context_type: context.dashboard_context_type,
      dashboard_context_id: context.dashboard_context_id,
      container_type: scope.container_type,
      container_id: scope.container_id,
      generated_at: generated_at,
      timezone: Map.get(custom, :timezone) || "Etc/UTC"
    })
  end

  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(list) when is_list(list), do: Map.new(list)
  defp normalize_map(_), do: %{}

  defp emit_assembly_telemetry({:ok, snapshot}, duration_ms) do
    Telemetry.assembly_stop(
      %{duration_ms: duration_ms},
      %{
        outcome: :ok,
        container_type: snapshot.scope.container_type,
        oracle_count: map_size(snapshot.oracles),
        status_count: map_size(snapshot.oracle_statuses)
      }
    )
  end

  defp emit_assembly_telemetry({:error, {:snapshot_assembly_failed, reason}}, duration_ms) do
    Telemetry.assembly_stop(
      %{duration_ms: duration_ms},
      %{
        outcome: :error,
        container_type: :unknown,
        error_type: error_type(reason)
      }
    )
  end

  defp log_assembly_result({:ok, snapshot}) do
    Logger.info(
      "snapshot assemble completed request_token=#{snapshot.request_token} oracle_count=#{map_size(snapshot.oracles)}"
    )
  end

  defp log_assembly_result({:error, {:snapshot_assembly_failed, reason}}) do
    Logger.error("snapshot assemble failed reason=#{inspect(reason)}")
  end

  defp error_type({type, _}) when is_atom(type), do: Atom.to_string(type)
  defp error_type(type) when is_atom(type), do: Atom.to_string(type)
  defp error_type(other), do: inspect(other)
end

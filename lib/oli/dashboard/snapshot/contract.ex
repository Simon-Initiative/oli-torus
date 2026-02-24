defmodule Oli.Dashboard.Snapshot.Contract do
  @moduledoc """
  Canonical snapshot contract for dashboard projection and export consumers.

  This module is intentionally transformation-only. It does not orchestrate
  request lifecycle, cache policy, or query execution.
  """

  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope

  @current_snapshot_version 1
  @current_projection_version 1
  @supported_snapshot_versions [1]
  @supported_projection_versions [1]

  @boundary_non_goals [
    :queue_token_orchestration,
    :cache_policy,
    :direct_oracle_queries,
    :direct_analytics_queries
  ]

  @projection_reason_codes [
    :missing_oracle_payload,
    :dependency_unavailable,
    :invalid_projection_data,
    :unsupported_projection,
    :projection_timeout,
    :projection_derivation_failed
  ]

  @export_reason_codes [
    :required_projection_unavailable,
    :required_projection_failed,
    :dataset_policy_excluded,
    :serializer_error,
    :zip_build_failed,
    :parity_mismatch,
    :export_timeout,
    :export_failed
  ]

  @enforce_keys [
    :snapshot_version,
    :projection_version,
    :request_token,
    :scope,
    :metadata,
    :oracles,
    :oracle_statuses,
    :projections,
    :projection_statuses
  ]
  defstruct [
    :snapshot_version,
    :projection_version,
    :request_token,
    :scope,
    :metadata,
    :oracles,
    :oracle_statuses,
    :projections,
    :projection_statuses
  ]

  @type projection_status_type :: :ready | :partial | :failed | :unavailable
  @type reason_code ::
          :missing_oracle_payload
          | :dependency_unavailable
          | :invalid_projection_data
          | :unsupported_projection
          | :projection_timeout
          | :projection_derivation_failed
          | :required_projection_unavailable
          | :required_projection_failed
          | :dataset_policy_excluded
          | :serializer_error
          | :zip_build_failed
          | :parity_mismatch
          | :export_timeout
          | :export_failed

  @type projection_status :: %{
          required(:status) => projection_status_type(),
          optional(:reason_code) => reason_code(),
          optional(:reason) => term(),
          optional(:details) => term()
        }

  @type metadata :: %{
          required(:dashboard_context_type) => OracleContext.dashboard_context_type(),
          required(:dashboard_context_id) => pos_integer(),
          required(:container_type) => Scope.container_type(),
          required(:container_id) => pos_integer() | nil,
          optional(atom() | String.t()) => term()
        }

  @type t :: %__MODULE__{
          snapshot_version: pos_integer(),
          projection_version: pos_integer(),
          request_token: String.t(),
          scope: Scope.t(),
          metadata: metadata(),
          oracles: map(),
          oracle_statuses: map(),
          projections: map(),
          projection_statuses: %{optional(atom() | String.t()) => projection_status()}
        }

  @type error :: {:invalid_snapshot_contract, term()}

  @type input :: map() | keyword()

  @allowed_input_keys [
    :snapshot_version,
    :projection_version,
    :request_token,
    :context,
    :scope,
    :metadata,
    :oracles,
    :oracle_statuses,
    :projections,
    :projection_statuses
  ]

  @doc """
  Builds a normalized snapshot contract from context-scoped inputs.
  """
  @spec new_snapshot(input()) :: {:ok, t()} | {:error, error()}
  def new_snapshot(input) when is_list(input), do: new_snapshot(Map.new(input))

  def new_snapshot(input) when is_map(input) do
    with {:ok, attrs} <- normalize_attrs(input),
         {:ok, request_token} <- normalize_request_token(Map.get(attrs, :request_token)),
         {:ok, context} <- normalize_context(Map.get(attrs, :context)),
         {:ok, scope} <- normalize_scope(Map.get(attrs, :scope), context),
         {:ok, snapshot_version} <- normalize_snapshot_version(Map.get(attrs, :snapshot_version)),
         {:ok, projection_version} <-
           normalize_projection_version(Map.get(attrs, :projection_version)),
         :ok <- ensure_version_compatibility(snapshot_version, projection_version),
         {:ok, metadata} <- normalize_metadata(Map.get(attrs, :metadata, %{}), context, scope),
         {:ok, oracles} <- normalize_map(Map.get(attrs, :oracles, %{}), :oracles),
         {:ok, oracle_statuses} <-
           normalize_map(Map.get(attrs, :oracle_statuses, %{}), :oracle_statuses),
         {:ok, projections} <- normalize_map(Map.get(attrs, :projections, %{}), :projections),
         {:ok, projection_statuses} <-
           normalize_projection_statuses(Map.get(attrs, :projection_statuses, %{})) do
      {:ok,
       %__MODULE__{
         snapshot_version: snapshot_version,
         projection_version: projection_version,
         request_token: request_token,
         scope: scope,
         metadata: metadata,
         oracles: oracles,
         oracle_statuses: oracle_statuses,
         projections: projections,
         projection_statuses: projection_statuses
       }}
    end
  end

  def new_snapshot(other), do: {:error, {:invalid_snapshot_contract, {:invalid_payload, other}}}

  @doc """
  Builds a validated projection status entry.
  """
  @spec new_projection_status(map() | keyword() | projection_status_type()) ::
          {:ok, projection_status()} | {:error, error()}
  def new_projection_status(status) when status in [:ready, :partial, :failed, :unavailable] do
    new_projection_status(%{status: status})
  end

  def new_projection_status(input) when is_list(input), do: new_projection_status(Map.new(input))

  def new_projection_status(%{} = input) do
    normalized_input = normalize_projection_status_input(input)

    with {:ok, status} <- normalize_projection_status_type(Map.get(normalized_input, :status)),
         {:ok, reason} <- normalize_optional_reason(Map.get(normalized_input, :reason)),
         {:ok, reason_code} <-
           normalize_reason_code(status, Map.get(normalized_input, :reason_code), reason),
         {:ok, details} <- normalize_optional_details(Map.get(normalized_input, :details)) do
      {:ok,
       %{status: status}
       |> maybe_put(:reason_code, reason_code)
       |> maybe_put(:reason, reason)
       |> maybe_put(:details, details)}
    end
  end

  def new_projection_status(other) do
    {:error, {:invalid_snapshot_contract, {:invalid_projection_status, other}}}
  end

  @doc """
  Current snapshot contract version.
  """
  @spec current_snapshot_version() :: pos_integer()
  def current_snapshot_version, do: @current_snapshot_version

  @doc """
  Current projection contract version.
  """
  @spec current_projection_version() :: pos_integer()
  def current_projection_version, do: @current_projection_version

  @doc """
  Returns supported snapshot versions for compatibility checks.
  """
  @spec supported_snapshot_versions() :: [pos_integer()]
  def supported_snapshot_versions, do: @supported_snapshot_versions

  @doc """
  Returns supported projection versions for compatibility checks.
  """
  @spec supported_projection_versions() :: [pos_integer()]
  def supported_projection_versions, do: @supported_projection_versions

  @doc """
  Checks if a snapshot version is supported.
  """
  @spec compatible_snapshot_version?(term()) :: boolean()
  def compatible_snapshot_version?(version) do
    case normalize_version_number(version, :snapshot_version) do
      {:ok, normalized} -> normalized in @supported_snapshot_versions
      _ -> false
    end
  end

  @doc """
  Checks if a projection version is supported.
  """
  @spec compatible_projection_version?(term()) :: boolean()
  def compatible_projection_version?(version) do
    case normalize_version_number(version, :projection_version) do
      {:ok, normalized} -> normalized in @supported_projection_versions
      _ -> false
    end
  end

  @doc """
  Checks compatibility for both snapshot and projection contract versions.
  """
  @spec compatible_versions?(term(), term()) :: boolean()
  def compatible_versions?(snapshot_version, projection_version) do
    compatible_snapshot_version?(snapshot_version) and
      compatible_projection_version?(projection_version)
  end

  @doc """
  Returns reason-code taxonomy for projection or export domains.
  """
  @spec reason_codes(:projection | :export) :: [reason_code()]
  def reason_codes(:projection), do: @projection_reason_codes
  def reason_codes(:export), do: @export_reason_codes

  @doc """
  Deterministically classifies projection failures.
  """
  @spec projection_reason_code(term()) :: reason_code()
  def projection_reason_code({:missing_oracle_payload, _}), do: :missing_oracle_payload
  def projection_reason_code({:oracle_missing, _}), do: :missing_oracle_payload
  def projection_reason_code(:missing_oracle_payload), do: :missing_oracle_payload
  def projection_reason_code({:dependency_unavailable, _}), do: :dependency_unavailable
  def projection_reason_code(:dependency_unavailable), do: :dependency_unavailable
  def projection_reason_code({:invalid_projection_data, _}), do: :invalid_projection_data
  def projection_reason_code(:invalid_projection_data), do: :invalid_projection_data
  def projection_reason_code({:unsupported_projection, _}), do: :unsupported_projection
  def projection_reason_code(:unsupported_projection), do: :unsupported_projection
  def projection_reason_code({:timeout, _}), do: :projection_timeout
  def projection_reason_code(:timeout), do: :projection_timeout
  def projection_reason_code({:exception, _}), do: :projection_derivation_failed
  def projection_reason_code(_), do: :projection_derivation_failed

  @doc """
  Deterministically classifies export failures.
  """
  @spec export_reason_code(term()) :: reason_code()
  def export_reason_code({:required_projection_unavailable, _}),
    do: :required_projection_unavailable

  def export_reason_code(:required_projection_unavailable), do: :required_projection_unavailable
  def export_reason_code({:required_projection_failed, _}), do: :required_projection_failed
  def export_reason_code(:required_projection_failed), do: :required_projection_failed
  def export_reason_code({:dataset_policy_excluded, _}), do: :dataset_policy_excluded
  def export_reason_code(:dataset_policy_excluded), do: :dataset_policy_excluded
  def export_reason_code({:serializer_error, _}), do: :serializer_error
  def export_reason_code(:serializer_error), do: :serializer_error
  def export_reason_code({:zip_build_failed, _}), do: :zip_build_failed
  def export_reason_code(:zip_build_failed), do: :zip_build_failed
  def export_reason_code({:parity_mismatch, _}), do: :parity_mismatch
  def export_reason_code(:parity_mismatch), do: :parity_mismatch
  def export_reason_code({:timeout, _}), do: :export_timeout
  def export_reason_code(:timeout), do: :export_timeout
  def export_reason_code(_), do: :export_failed

  @doc """
  Explicitly documents concerns that are intentionally excluded from the snapshot contract layer.
  """
  @spec boundary_non_goals() :: [atom()]
  def boundary_non_goals, do: @boundary_non_goals

  defp normalize_attrs(attrs) do
    Enum.reduce(attrs, {:ok, %{}, []}, fn {raw_key, value}, {:ok, normalized, unknown} ->
      case normalize_input_key(raw_key) do
        {:ok, key} -> {:ok, Map.put(normalized, key, value), unknown}
        :error -> {:ok, normalized, [raw_key | unknown]}
      end
    end)
    |> case do
      {:ok, normalized, []} ->
        {:ok, normalized}

      {:ok, _normalized, unknown} ->
        {:error,
         {:invalid_snapshot_contract,
          {:unknown_fields, unknown |> Enum.map(&inspect/1) |> Enum.sort()}}}
    end
  end

  defp normalize_input_key(key) when key in @allowed_input_keys, do: {:ok, key}
  defp normalize_input_key("snapshot_version"), do: {:ok, :snapshot_version}
  defp normalize_input_key("projection_version"), do: {:ok, :projection_version}
  defp normalize_input_key("request_token"), do: {:ok, :request_token}
  defp normalize_input_key("context"), do: {:ok, :context}
  defp normalize_input_key("scope"), do: {:ok, :scope}
  defp normalize_input_key("metadata"), do: {:ok, :metadata}
  defp normalize_input_key("oracles"), do: {:ok, :oracles}
  defp normalize_input_key("oracle_statuses"), do: {:ok, :oracle_statuses}
  defp normalize_input_key("projections"), do: {:ok, :projections}
  defp normalize_input_key("projection_statuses"), do: {:ok, :projection_statuses}
  defp normalize_input_key(_), do: :error

  defp normalize_request_token(token) when is_binary(token) and byte_size(token) > 0 do
    {:ok, token}
  end

  defp normalize_request_token(other) do
    {:error, {:invalid_snapshot_contract, {:invalid_request_token, other}}}
  end

  defp normalize_context(nil) do
    {:error, {:invalid_snapshot_contract, :missing_context}}
  end

  defp normalize_context(context_input) do
    case OracleContext.new(context_input) do
      {:ok, context} -> {:ok, context}
      {:error, reason} -> {:error, {:invalid_snapshot_contract, {:invalid_context, reason}}}
    end
  end

  defp normalize_scope(nil, %OracleContext{scope: scope}), do: {:ok, scope}

  defp normalize_scope(scope_input, %OracleContext{scope: context_scope}) do
    case Scope.new(scope_input) do
      {:ok, scope} ->
        if Scope.container_key(scope) == Scope.container_key(context_scope) do
          {:ok, scope}
        else
          {:error,
           {:invalid_snapshot_contract,
            {:scope_context_mismatch,
             %{
               scope: Scope.container_key(scope),
               context_scope: Scope.container_key(context_scope)
             }}}}
        end

      {:error, reason} ->
        {:error, {:invalid_snapshot_contract, {:invalid_scope, reason}}}
    end
  end

  defp normalize_snapshot_version(nil), do: {:ok, @current_snapshot_version}

  defp normalize_snapshot_version(version),
    do: normalize_version_number(version, :snapshot_version)

  defp normalize_projection_version(nil), do: {:ok, @current_projection_version}

  defp normalize_projection_version(version),
    do: normalize_version_number(version, :projection_version)

  defp normalize_version_number(version, _field) when is_integer(version) and version > 0,
    do: {:ok, version}

  defp normalize_version_number(version, field) when is_binary(version) do
    case Integer.parse(version) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, {:invalid_snapshot_contract, {:invalid_version, field, version}}}
    end
  end

  defp normalize_version_number(version, field) do
    {:error, {:invalid_snapshot_contract, {:invalid_version, field, version}}}
  end

  defp ensure_version_compatibility(snapshot_version, projection_version) do
    cond do
      snapshot_version not in @supported_snapshot_versions ->
        {:error, {:invalid_snapshot_contract, {:unsupported_snapshot_version, snapshot_version}}}

      projection_version not in @supported_projection_versions ->
        {:error,
         {:invalid_snapshot_contract, {:unsupported_projection_version, projection_version}}}

      true ->
        :ok
    end
  end

  defp normalize_metadata(input, %OracleContext{} = context, %Scope{} = scope)
       when is_list(input) do
    normalize_metadata(Map.new(input), context, scope)
  end

  defp normalize_metadata(input, %OracleContext{} = context, %Scope{} = scope)
       when is_map(input) do
    normalized =
      Enum.reduce(input, %{}, fn {key, value}, acc ->
        case normalize_metadata_key(key) do
          {:ok, normalized_key} -> Map.put(acc, normalized_key, value)
          :error -> acc
        end
      end)

    derived = derived_metadata(context, scope)

    with :ok <- validate_metadata_identity(normalized, derived) do
      {:ok, Map.merge(normalized, derived)}
    end
  end

  defp normalize_metadata(other, _context, _scope) do
    {:error, {:invalid_snapshot_contract, {:invalid_metadata, other}}}
  end

  defp normalize_metadata_key(key) when is_atom(key), do: {:ok, key}
  defp normalize_metadata_key("dashboard_context_type"), do: {:ok, :dashboard_context_type}
  defp normalize_metadata_key("dashboard_context_id"), do: {:ok, :dashboard_context_id}
  defp normalize_metadata_key("container_type"), do: {:ok, :container_type}
  defp normalize_metadata_key("container_id"), do: {:ok, :container_id}
  defp normalize_metadata_key(key) when is_binary(key), do: {:ok, key}
  defp normalize_metadata_key(_), do: :error

  defp derived_metadata(%OracleContext{} = context, %Scope{} = scope) do
    %{
      dashboard_context_type: context.dashboard_context_type,
      dashboard_context_id: context.dashboard_context_id,
      container_type: scope.container_type,
      container_id: scope.container_id
    }
  end

  defp validate_metadata_identity(metadata, derived) do
    case Enum.find(
           [:dashboard_context_type, :dashboard_context_id, :container_type, :container_id],
           fn key ->
             Map.has_key?(metadata, key) and Map.get(metadata, key) != Map.get(derived, key)
           end
         ) do
      nil ->
        :ok

      mismatched_key ->
        {:error,
         {:invalid_snapshot_contract,
          {:metadata_identity_mismatch, mismatched_key,
           %{
             expected: Map.get(derived, mismatched_key),
             actual: Map.get(metadata, mismatched_key)
           }}}}
    end
  end

  defp normalize_map(value, _field) when is_map(value), do: {:ok, value}
  defp normalize_map(value, field), do: {:error, {:invalid_snapshot_contract, {field, value}}}

  defp normalize_projection_statuses(value) when is_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {capability, status_input}, {:ok, acc} ->
      case new_projection_status(status_input) do
        {:ok, status} ->
          {:cont, {:ok, Map.put(acc, capability, status)}}

        {:error, reason} ->
          {:halt,
           {:error, {:invalid_snapshot_contract, {:projection_status, capability, reason}}}}
      end
    end)
  end

  defp normalize_projection_statuses(other) do
    {:error, {:invalid_snapshot_contract, {:projection_statuses, other}}}
  end

  defp normalize_projection_status_type(status)
       when status in [:ready, :partial, :failed, :unavailable],
       do: {:ok, status}

  defp normalize_projection_status_type(other) do
    {:error, {:invalid_snapshot_contract, {:invalid_projection_status_type, other}}}
  end

  defp normalize_optional_reason(nil), do: {:ok, nil}
  defp normalize_optional_reason(reason), do: {:ok, reason}

  defp normalize_reason_code(:ready, nil, _reason), do: {:ok, nil}

  defp normalize_reason_code(status, nil, nil) when status in [:partial, :failed, :unavailable] do
    {:error, {:invalid_snapshot_contract, {:missing_reason_code, status}}}
  end

  defp normalize_reason_code(status, nil, reason)
       when status in [:partial, :failed, :unavailable] do
    code = projection_reason_code(reason)
    {:ok, code}
  end

  defp normalize_reason_code(_status, reason_code, _reason)
       when reason_code in @projection_reason_codes,
       do: {:ok, reason_code}

  defp normalize_reason_code(_status, reason_code, _reason) do
    {:error, {:invalid_snapshot_contract, {:invalid_reason_code, reason_code}}}
  end

  defp normalize_optional_details(nil), do: {:ok, nil}
  defp normalize_optional_details(details), do: {:ok, details}

  defp normalize_projection_status_input(input) do
    Enum.reduce(input, %{}, fn
      {key, value}, acc when key in [:status, :reason_code, :reason, :details] ->
        Map.put(acc, key, value)

      {"status", value}, acc ->
        Map.put(acc, :status, value)

      {"reason_code", value}, acc ->
        Map.put(acc, :reason_code, value)

      {"reason", value}, acc ->
        Map.put(acc, :reason, value)

      {"details", value}, acc ->
        Map.put(acc, :details, value)

      {_ignored_key, _ignored_value}, acc ->
        acc
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

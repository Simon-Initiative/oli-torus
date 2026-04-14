defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Helpers do
  @moduledoc false

  alias Oli.Dashboard.Snapshot.Contract

  @type oracle_key :: atom() | String.t()
  @type error :: {:missing_required_oracles, [oracle_key()]}

  @spec require_oracles(Contract.t(), [oracle_key()]) :: {:ok, map()} | {:error, error()}
  def require_oracles(%Contract{} = snapshot, oracle_keys) do
    {available, missing} =
      Enum.reduce(oracle_keys, {%{}, []}, fn key, {available_acc, missing_acc} ->
        case Map.fetch(snapshot.oracles, key) do
          {:ok, payload} -> {Map.put(available_acc, key, payload), missing_acc}
          :error -> {available_acc, [key | missing_acc]}
        end
      end)

    case Enum.reverse(missing) do
      [] -> {:ok, available}
      missing_keys -> {:error, {:missing_required_oracles, missing_keys}}
    end
  end

  @spec optional_oracles(Contract.t(), [oracle_key()]) :: map()
  def optional_oracles(%Contract{} = snapshot, oracle_keys) do
    Enum.reduce(oracle_keys, %{}, fn key, acc ->
      case Map.fetch(snapshot.oracles, key) do
        {:ok, payload} -> Map.put(acc, key, payload)
        :error -> acc
      end
    end)
  end

  @spec missing_optional_oracles(Contract.t(), [oracle_key()]) :: [oracle_key()]
  def missing_optional_oracles(%Contract{} = snapshot, oracle_keys) do
    Enum.reject(oracle_keys, &Map.has_key?(snapshot.oracles, &1))
  end

  @spec projection_base(Contract.t(), atom(), map()) :: map()
  def projection_base(%Contract{} = snapshot, capability_key, values) do
    Map.merge(
      %{
        capability: capability_key,
        request_token: snapshot.request_token,
        snapshot_version: snapshot.snapshot_version,
        projection_version: snapshot.projection_version
      },
      values
    )
  end
end

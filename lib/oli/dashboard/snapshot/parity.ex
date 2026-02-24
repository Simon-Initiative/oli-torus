defmodule Oli.Dashboard.Snapshot.Parity do
  @moduledoc """
  Snapshot parity fingerprint helpers for UI/CSV equivalence checks.
  """

  @type fingerprint :: String.t()

  @spec fingerprint(map(), list()) :: fingerprint()
  def fingerprint(snapshot_bundle, dataset_specs) do
    snapshot = Map.get(snapshot_bundle, :snapshot, %{})

    payload =
      %{
        request_token: Map.get(snapshot_bundle, :request_token),
        snapshot_version: Map.get(snapshot, :snapshot_version),
        projection_version: Map.get(snapshot, :projection_version),
        projection_statuses:
          normalize_projection_statuses(Map.get(snapshot_bundle, :projection_statuses, %{})),
        dataset_ids: normalize_dataset_ids(dataset_specs)
      }

    payload
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec compare(fingerprint(), fingerprint()) ::
          :match | {:mismatch, %{expected: fingerprint(), actual: fingerprint()}}
  def compare(expected, actual) when expected == actual, do: :match

  def compare(expected, actual),
    do: {:mismatch, %{expected: expected, actual: actual}}

  defp normalize_projection_statuses(statuses) when is_map(statuses) do
    statuses
    |> Enum.map(fn {capability, status} ->
      {to_string(capability), normalize_status(status)}
    end)
    |> Enum.sort_by(fn {capability, _status} -> capability end)
  end

  defp normalize_projection_statuses(_), do: []

  defp normalize_status(%{} = status) do
    %{
      status: Map.get(status, :status),
      reason_code: Map.get(status, :reason_code)
    }
  end

  defp normalize_status(other), do: %{status: :unknown, reason_code: inspect(other)}

  defp normalize_dataset_ids(dataset_specs) do
    dataset_specs
    |> Enum.map(&Map.get(&1, :dataset_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.sort()
  end
end

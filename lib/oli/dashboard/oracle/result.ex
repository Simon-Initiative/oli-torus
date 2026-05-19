defmodule Oli.Dashboard.Oracle.Result do
  @moduledoc """
  Oracle result envelope helpers for runtime, caching, and snapshot consumers.

  Metadata is sanitized to avoid leaking nested/raw payload content in logs and
  telemetry metadata paths.
  """

  alias Oli.Dashboard.OracleTelemetry

  @type metadata_value :: String.t() | number() | boolean() | atom() | nil | :redacted
  @type metadata :: %{optional(atom() | String.t()) => metadata_value()}

  @type t ::
          %{
            required(:status) => :ok | :error,
            required(:oracle_key) => atom(),
            required(:oracle_version) => non_neg_integer(),
            required(:stale?) => boolean(),
            required(:metadata) => metadata(),
            optional(:payload) => term(),
            optional(:reason) => term()
          }

  @spec ok(atom(), term(), keyword()) :: t()
  def ok(oracle_key, payload, opts \\ []) when is_atom(oracle_key) and is_list(opts) do
    base_envelope(oracle_key, opts)
    |> Map.put(:status, :ok)
    |> Map.put(:payload, payload)
  end

  @spec error(atom(), term(), keyword()) :: t()
  def error(oracle_key, reason, opts \\ []) when is_atom(oracle_key) and is_list(opts) do
    OracleTelemetry.contract_error(%{
      dashboard_product: dashboard_product(opts),
      oracle_key: oracle_key,
      outcome: :error,
      error_type: reason_type(reason),
      event: :contract
    })

    base_envelope(oracle_key, opts)
    |> Map.put(:status, :error)
    |> Map.put(:reason, reason)
  end

  @spec stale?(map()) :: boolean()
  def stale?(%{stale?: stale}) when is_boolean(stale), do: stale
  def stale?(_), do: false

  defp base_envelope(oracle_key, opts) do
    %{
      oracle_key: oracle_key,
      oracle_version: normalize_version(Keyword.get(opts, :version, 1)),
      stale?: Keyword.get(opts, :stale, false),
      metadata: sanitize_metadata(Keyword.get(opts, :metadata, %{}))
    }
  end

  defp normalize_version(version) when is_integer(version) and version >= 0, do: version
  defp normalize_version(_), do: 0

  defp sanitize_metadata(metadata) when is_list(metadata),
    do: sanitize_metadata(Map.new(metadata))

  defp sanitize_metadata(metadata) when is_map(metadata) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      case valid_metadata_key?(key) do
        true -> Map.put(acc, key, sanitize_metadata_value(value))
        false -> acc
      end
    end)
  end

  defp sanitize_metadata(_), do: %{}

  defp valid_metadata_key?(key) when is_atom(key), do: true
  defp valid_metadata_key?(key) when is_binary(key), do: true
  defp valid_metadata_key?(_), do: false

  defp sanitize_metadata_value(value) when is_binary(value), do: value
  defp sanitize_metadata_value(value) when is_boolean(value), do: value
  defp sanitize_metadata_value(value) when is_number(value), do: value
  defp sanitize_metadata_value(value) when is_atom(value), do: value
  defp sanitize_metadata_value(nil), do: nil
  defp sanitize_metadata_value(_), do: :redacted

  defp reason_type({type, _}) when is_atom(type), do: type
  defp reason_type(type) when is_atom(type), do: type
  defp reason_type(_), do: :unknown

  defp dashboard_product(opts) do
    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> case do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
        _ -> %{}
      end

    Map.get(metadata, :dashboard_product) || Map.get(metadata, "dashboard_product") || :unknown
  end
end

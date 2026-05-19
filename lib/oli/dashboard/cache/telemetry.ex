defmodule Oli.Dashboard.Cache.Telemetry do
  @moduledoc """
  Telemetry helpers for dashboard cache outcomes.

  Metadata emitted from this module is intentionally PII-safe and excludes user id,
  dashboard context id, container id, and payload content.
  """

  @lookup_stop_event [:oli, :dashboard, :cache, :lookup, :stop]
  @write_stop_event [:oli, :dashboard, :cache, :write, :stop]
  @coalescing_claim_event [:oli, :dashboard, :cache, :coalescing, :claim]

  @typedoc "PII-safe metadata schema for lookup outcomes."
  @type lookup_metadata :: %{
          required(:cache_tier) => :inprocess | :revisit | :mixed | :unknown,
          required(:outcome) => :hit | :miss | :partial | :error | :expired | :skipped | :unknown,
          required(:container_type) => :course | :container | :unknown,
          optional(:oracle_key) => atom() | String.t(),
          optional(:oracle_key_count) => non_neg_integer(),
          optional(:miss_count) => non_neg_integer(),
          optional(:expired_count) => non_neg_integer(),
          optional(:dashboard_context_type) => :section | :project | :unknown,
          optional(:error_type) => String.t()
        }

  @typedoc "PII-safe metadata schema for write outcomes."
  @type write_metadata :: %{
          required(:cache_tier) => :inprocess | :revisit | :mixed | :unknown,
          required(:outcome) => :accepted | :rejected | :error | :unknown,
          required(:container_type) => :course | :container | :unknown,
          optional(:oracle_key) => atom() | String.t(),
          optional(:write_mode) => :active | :late | :unknown,
          optional(:pruned_expired_count) => non_neg_integer(),
          optional(:evicted_count) => non_neg_integer(),
          optional(:entry_count) => non_neg_integer(),
          optional(:error_type) => String.t()
        }

  @typedoc "PII-safe metadata schema for coalescing claim outcomes."
  @type coalescing_metadata :: %{
          required(:outcome) =>
            :coalesced_producer
            | :coalesced_waiter
            | :coalescer_fallback
            | :coalescer_error
            | :unknown,
          optional(:error_type) => String.t()
        }

  @doc "Returns telemetry events emitted by cache telemetry helpers."
  @spec events() :: [list(atom())]
  def events, do: [@lookup_stop_event, @write_stop_event, @coalescing_claim_event]

  @doc "Returns lookup metadata schema used by cache outcome events."
  @spec lookup_metadata_schema() :: map()
  def lookup_metadata_schema do
    %{
      required: [:cache_tier, :outcome, :container_type],
      optional: [
        :oracle_key,
        :oracle_key_count,
        :miss_count,
        :expired_count,
        :dashboard_context_type,
        :error_type
      ],
      forbidden_pii: [:user_id, :dashboard_context_id, :container_id, :payload]
    }
  end

  @doc "Returns write metadata schema used by cache outcome events."
  @spec write_metadata_schema() :: map()
  def write_metadata_schema do
    %{
      required: [:cache_tier, :outcome, :container_type],
      optional: [
        :oracle_key,
        :write_mode,
        :pruned_expired_count,
        :evicted_count,
        :entry_count,
        :error_type
      ],
      forbidden_pii: [:user_id, :dashboard_context_id, :container_id, :payload]
    }
  end

  @doc "Returns coalescing metadata schema used by cache claim events."
  @spec coalescing_metadata_schema() :: map()
  def coalescing_metadata_schema do
    %{
      required: [:outcome],
      optional: [:error_type],
      forbidden_pii: [:user_id, :dashboard_context_id, :container_id, :payload]
    }
  end

  @doc "Emits cache lookup stop telemetry with PII-safe metadata normalization."
  @spec lookup_stop(map(), map() | keyword()) :: :ok
  def lookup_stop(measurements, metadata) do
    :telemetry.execute(
      @lookup_stop_event,
      normalize_measurements(measurements),
      sanitize_lookup_metadata(metadata)
    )
  end

  @doc "Emits cache write stop telemetry with PII-safe metadata normalization."
  @spec write_stop(map(), map() | keyword()) :: :ok
  def write_stop(measurements, metadata) do
    :telemetry.execute(
      @write_stop_event,
      normalize_measurements(measurements),
      sanitize_write_metadata(metadata)
    )
  end

  @doc "Emits cache coalescing claim telemetry with PII-safe metadata normalization."
  @spec coalescing_claim(map() | keyword()) :: :ok
  def coalescing_claim(metadata) do
    :telemetry.execute(
      @coalescing_claim_event,
      %{count: 1},
      sanitize_coalescing_metadata(metadata)
    )
  end

  @doc "Normalizes lookup metadata to a strict PII-safe schema."
  @spec sanitize_lookup_metadata(map() | keyword()) :: lookup_metadata()
  def sanitize_lookup_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      cache_tier: normalize_cache_tier(Map.get(normalized, :cache_tier)),
      outcome: normalize_lookup_outcome(Map.get(normalized, :outcome)),
      container_type: normalize_container_type(Map.get(normalized, :container_type)),
      oracle_key: normalize_oracle_key(Map.get(normalized, :oracle_key)),
      oracle_key_count: normalize_non_negative_integer(Map.get(normalized, :oracle_key_count)),
      miss_count: normalize_non_negative_integer(Map.get(normalized, :miss_count)),
      expired_count: normalize_non_negative_integer(Map.get(normalized, :expired_count)),
      dashboard_context_type:
        normalize_dashboard_context_type(Map.get(normalized, :dashboard_context_type)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc "Normalizes write metadata to a strict PII-safe schema."
  @spec sanitize_write_metadata(map() | keyword()) :: write_metadata()
  def sanitize_write_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      cache_tier: normalize_cache_tier(Map.get(normalized, :cache_tier)),
      outcome: normalize_write_outcome(Map.get(normalized, :outcome)),
      container_type: normalize_container_type(Map.get(normalized, :container_type)),
      oracle_key: normalize_oracle_key(Map.get(normalized, :oracle_key)),
      write_mode: normalize_write_mode(Map.get(normalized, :write_mode)),
      pruned_expired_count:
        normalize_non_negative_integer(Map.get(normalized, :pruned_expired_count)),
      evicted_count: normalize_non_negative_integer(Map.get(normalized, :evicted_count)),
      entry_count: normalize_non_negative_integer(Map.get(normalized, :entry_count)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc "Normalizes coalescing metadata to a strict PII-safe schema."
  @spec sanitize_coalescing_metadata(map() | keyword()) :: coalescing_metadata()
  def sanitize_coalescing_metadata(metadata) do
    normalized = normalize_input_metadata(metadata)

    %{
      outcome: normalize_coalescing_outcome(Map.get(normalized, :outcome)),
      error_type: normalize_error_type(Map.get(normalized, :error_type))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
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

  defp normalize_cache_tier(:inprocess), do: :inprocess
  defp normalize_cache_tier(:revisit), do: :revisit
  defp normalize_cache_tier(:mixed), do: :mixed
  defp normalize_cache_tier(_), do: :unknown

  defp normalize_lookup_outcome(:hit), do: :hit
  defp normalize_lookup_outcome(:miss), do: :miss
  defp normalize_lookup_outcome(:partial), do: :partial
  defp normalize_lookup_outcome(:error), do: :error
  defp normalize_lookup_outcome(:expired), do: :expired
  defp normalize_lookup_outcome(:skipped), do: :skipped
  defp normalize_lookup_outcome(_), do: :unknown

  defp normalize_write_outcome(:accepted), do: :accepted
  defp normalize_write_outcome(:rejected), do: :rejected
  defp normalize_write_outcome(:error), do: :error
  defp normalize_write_outcome(_), do: :unknown

  defp normalize_coalescing_outcome(:coalesced_producer), do: :coalesced_producer
  defp normalize_coalescing_outcome(:coalesced_waiter), do: :coalesced_waiter
  defp normalize_coalescing_outcome(:coalescer_fallback), do: :coalescer_fallback
  defp normalize_coalescing_outcome(:coalescer_error), do: :coalescer_error
  defp normalize_coalescing_outcome(_), do: :unknown

  defp normalize_container_type(:course), do: :course
  defp normalize_container_type(:container), do: :container
  defp normalize_container_type(_), do: :unknown

  defp normalize_dashboard_context_type(:section), do: :section
  defp normalize_dashboard_context_type(:project), do: :project
  defp normalize_dashboard_context_type(nil), do: nil
  defp normalize_dashboard_context_type(_), do: :unknown

  defp normalize_oracle_key(value) when is_atom(value), do: value
  defp normalize_oracle_key(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp normalize_oracle_key(_), do: nil

  defp normalize_write_mode(:active), do: :active
  defp normalize_write_mode(:late), do: :late
  defp normalize_write_mode(nil), do: nil
  defp normalize_write_mode(_), do: :unknown

  defp normalize_error_type(value) when is_binary(value), do: value
  defp normalize_error_type(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_error_type(nil), do: nil
  defp normalize_error_type(other), do: inspect(other)

  defp normalize_non_negative_integer(value) when is_integer(value) and value >= 0, do: value
  defp normalize_non_negative_integer(_), do: nil
end

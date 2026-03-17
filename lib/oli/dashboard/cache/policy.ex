defmodule Oli.Dashboard.Cache.Policy do
  @moduledoc """
  Configuration readers for cache TTL and enrollment-tiered container limits.
  """

  @default_inprocess_ttl_minutes 15
  @default_revisit_ttl_minutes 5
  @default_revisit_max_entries 10_000
  @default_revisit_write_sweep_interval 100
  @default_small_enrollment_threshold 20
  @default_normal_enrollment_threshold 200
  @default_small_max_containers 12
  @default_normal_max_containers 24
  @default_large_max_containers 36

  @env_inprocess_ttl "INSTRUCTOR_DASHBOARD_INPROCESS_CACHE_TTL_MINUTES"
  @env_revisit_ttl "INSTRUCTOR_DASHBOARD_REVISIT_CACHE_TTL_MINUTES"
  @env_revisit_max_entries "INSTRUCTOR_DASHBOARD_REVISIT_CACHE_MAX_ENTRIES"
  @env_revisit_write_sweep_interval "INSTRUCTOR_DASHBOARD_REVISIT_CACHE_WRITE_SWEEP_INTERVAL"
  @env_small_enrollment_threshold "INSTRUCTOR_DASHBOARD_CACHE_SMALL_ENROLLMENT_THRESHOLD"
  @env_normal_enrollment_threshold "INSTRUCTOR_DASHBOARD_CACHE_NORMAL_ENROLLMENT_THRESHOLD"
  @env_small_max_containers "INSTRUCTOR_DASHBOARD_CACHE_SMALL_MAX_CONTAINERS"
  @env_normal_max_containers "INSTRUCTOR_DASHBOARD_CACHE_NORMAL_MAX_CONTAINERS"
  @env_large_max_containers "INSTRUCTOR_DASHBOARD_CACHE_LARGE_MAX_CONTAINERS"

  @typedoc "Cache enrollment tier used for container-cap policy."
  @type enrollment_tier :: :small | :normal | :large

  @typedoc "Materialized policy values for deterministic usage in cache modules."
  @type snapshot :: %{
          inprocess_ttl_minutes: pos_integer(),
          revisit_ttl_minutes: pos_integer(),
          revisit_max_entries: pos_integer(),
          revisit_write_sweep_interval: pos_integer(),
          small_enrollment_threshold: pos_integer(),
          normal_enrollment_threshold: pos_integer(),
          small_max_containers: pos_integer(),
          normal_max_containers: pos_integer(),
          large_max_containers: pos_integer()
        }

  @doc "Returns in-process cache TTL in minutes."
  @spec inprocess_ttl_minutes() :: pos_integer()
  def inprocess_ttl_minutes do
    read_positive_integer(
      :inprocess_ttl_minutes,
      @env_inprocess_ttl,
      @default_inprocess_ttl_minutes
    )
  end

  @doc "Returns revisit cache TTL in minutes."
  @spec revisit_ttl_minutes() :: pos_integer()
  def revisit_ttl_minutes do
    read_positive_integer(:revisit_ttl_minutes, @env_revisit_ttl, @default_revisit_ttl_minutes)
  end

  @doc "Returns in-process cache TTL in milliseconds."
  @spec inprocess_ttl_ms() :: pos_integer()
  def inprocess_ttl_ms do
    :timer.minutes(inprocess_ttl_minutes())
  end

  @doc "Returns revisit cache TTL in milliseconds."
  @spec revisit_ttl_ms() :: pos_integer()
  def revisit_ttl_ms do
    :timer.minutes(revisit_ttl_minutes())
  end

  @doc "Returns revisit cache max entries bound."
  @spec revisit_max_entries() :: pos_integer()
  def revisit_max_entries do
    read_positive_integer(
      :revisit_max_entries,
      @env_revisit_max_entries,
      @default_revisit_max_entries
    )
  end

  @doc "Returns revisit cache write sweep interval (writes between full expiry sweeps)."
  @spec revisit_write_sweep_interval() :: pos_integer()
  def revisit_write_sweep_interval do
    read_positive_integer(
      :revisit_write_sweep_interval,
      @env_revisit_write_sweep_interval,
      @default_revisit_write_sweep_interval
    )
  end

  @doc "Returns enrollment tier for a section enrollment count."
  @spec tier_for_enrollment(non_neg_integer()) :: enrollment_tier()
  def tier_for_enrollment(enrollment_count)
      when is_integer(enrollment_count) and enrollment_count >= 0 do
    policy = snapshot()

    case enrollment_count do
      value when value <= policy.small_enrollment_threshold -> :small
      value when value <= policy.normal_enrollment_threshold -> :normal
      _ -> :large
    end
  end

  def tier_for_enrollment(_), do: :large

  @doc "Returns max containers allowed for a section enrollment count."
  @spec container_cap_for_enrollment(non_neg_integer()) :: pos_integer()
  def container_cap_for_enrollment(enrollment_count) do
    policy = snapshot()

    case tier_for_enrollment(enrollment_count) do
      :small -> policy.small_max_containers
      :normal -> policy.normal_max_containers
      :large -> policy.large_max_containers
    end
  end

  @doc "Returns normalized cache policy values."
  @spec snapshot() :: snapshot()
  def snapshot do
    raw_small_enrollment_threshold =
      read_positive_integer(
        :small_enrollment_threshold,
        @env_small_enrollment_threshold,
        @default_small_enrollment_threshold
      )

    raw_normal_enrollment_threshold =
      read_positive_integer(
        :normal_enrollment_threshold,
        @env_normal_enrollment_threshold,
        @default_normal_enrollment_threshold
      )

    small_enrollment_threshold =
      min(raw_small_enrollment_threshold, raw_normal_enrollment_threshold)

    normal_enrollment_threshold =
      max(raw_small_enrollment_threshold, raw_normal_enrollment_threshold)

    %{
      inprocess_ttl_minutes: inprocess_ttl_minutes(),
      revisit_ttl_minutes: revisit_ttl_minutes(),
      revisit_max_entries: revisit_max_entries(),
      revisit_write_sweep_interval: revisit_write_sweep_interval(),
      small_enrollment_threshold: small_enrollment_threshold,
      normal_enrollment_threshold: normal_enrollment_threshold,
      small_max_containers:
        read_positive_integer(
          :small_max_containers,
          @env_small_max_containers,
          @default_small_max_containers
        ),
      normal_max_containers:
        read_positive_integer(
          :normal_max_containers,
          @env_normal_max_containers,
          @default_normal_max_containers
        ),
      large_max_containers:
        read_positive_integer(
          :large_max_containers,
          @env_large_max_containers,
          @default_large_max_containers
        )
    }
  end

  defp read_positive_integer(config_key, env_key, default) do
    case configured_value(config_key, env_key) do
      value when is_integer(value) and value > 0 ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} when parsed > 0 -> parsed
          _ -> default
        end

      _ ->
        default
    end
  end

  defp configured_value(config_key, env_key) do
    module_config = Application.get_env(:oli, __MODULE__, %{})

    case Map.fetch(module_config, config_key) do
      {:ok, value} ->
        value

      :error ->
        System.get_env(env_key)
    end
  end
end

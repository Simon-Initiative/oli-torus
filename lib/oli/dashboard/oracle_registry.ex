defmodule Oli.Dashboard.OracleRegistry do
  @moduledoc """
  Shared registry contract and map-backed helpers for oracle dependency resolution.

  Shared modules in `Oli.Dashboard.*` define reusable contracts. Product-specific
  registries (for example `Oli.InstructorDashboard.*`) should provide the concrete
  dependency and oracle-module mappings while keeping this interface stable.
  """

  alias Oli.Dashboard.OracleDependencyPlanner
  alias Oli.Dashboard.OracleTelemetry

  @type consumer_key :: atom()
  @type oracle_key :: atom()

  @type dependency_profile :: %{
          required: [oracle_key()],
          optional: [oracle_key()]
        }

  @type registry :: %{
          optional(:dashboard_product) => atom() | String.t(),
          required(:consumers) => %{optional(consumer_key()) => dependency_profile() | map()},
          required(:oracles) => %{optional(oracle_key()) => module()}
        }

  @type error ::
          {:unknown_consumer, consumer_key()}
          | {:unknown_oracle, oracle_key()}
          | {:invalid_dependency_profile, term()}
          | {:oracle_dependency_cycle, [oracle_key()]}

  @callback dependencies_for(registry(), consumer_key()) ::
              {:ok, dependency_profile()} | {:error, error()}
  @callback required_for(registry(), consumer_key()) :: {:ok, [oracle_key()]} | {:error, error()}
  @callback optional_for(registry(), consumer_key()) :: {:ok, [oracle_key()]} | {:error, error()}
  @callback oracle_module(registry(), oracle_key()) :: {:ok, module()} | {:error, error()}
  @callback execution_plan_for(registry(), [oracle_key()]) ::
              {:ok, [[oracle_key()]]} | {:error, error()}
  @callback known_consumers(registry()) :: [consumer_key()]

  @spec dependencies_for(registry(), consumer_key()) ::
          {:ok, dependency_profile()} | {:error, error()}
  def dependencies_for(registry, consumer_key) when is_atom(consumer_key) do
    started_at = System.monotonic_time()

    result =
      with {:ok, consumers} <- consumers(registry),
           {:ok, profile} <- fetch_consumer_profile(consumers, consumer_key),
           {:ok, normalized_profile} <- normalize_profile(profile) do
        {:ok, normalized_profile}
      end

    emit_registry_resolve_stop(registry, consumer_key, result, started_at)
    result
  end

  def dependencies_for(registry, consumer_key) do
    started_at = System.monotonic_time()
    result = {:error, {:invalid_dependency_profile, {:invalid_consumer_key, consumer_key}}}
    emit_registry_resolve_stop(registry, nil, result, started_at)
    result
  end

  @spec required_for(registry(), consumer_key()) :: {:ok, [oracle_key()]} | {:error, error()}
  def required_for(registry, consumer_key) do
    with {:ok, %{required: required}} <- dependencies_for(registry, consumer_key) do
      {:ok, required}
    end
  end

  @spec optional_for(registry(), consumer_key()) :: {:ok, [oracle_key()]} | {:error, error()}
  def optional_for(registry, consumer_key) do
    with {:ok, %{optional: optional}} <- dependencies_for(registry, consumer_key) do
      {:ok, optional}
    end
  end

  @spec oracle_module(registry(), oracle_key()) :: {:ok, module()} | {:error, error()}
  def oracle_module(registry, oracle_key) when is_atom(oracle_key) do
    started_at = System.monotonic_time()

    result =
      with {:ok, oracle_modules} <- oracle_modules(registry) do
        case Map.get(oracle_modules, oracle_key) do
          module when is_atom(module) and not is_nil(module) ->
            {:ok, module}

          nil ->
            {:error, {:unknown_oracle, oracle_key}}

          invalid_module ->
            {:error,
             {:invalid_dependency_profile, {:invalid_oracle_module, oracle_key, invalid_module}}}
        end
      end

    emit_registry_lookup_stop(registry, oracle_key, result, started_at)
    result
  end

  def oracle_module(registry, oracle_key) do
    started_at = System.monotonic_time()
    result = {:error, {:invalid_dependency_profile, {:invalid_oracle_key, oracle_key}}}
    emit_registry_lookup_stop(registry, nil, result, started_at)
    result
  end

  @spec execution_plan_for(registry(), [oracle_key()]) ::
          {:ok, [[oracle_key()]]} | {:error, error()}
  def execution_plan_for(registry, oracle_keys) do
    with {:ok, requested_oracle_keys} <- normalize_requested_oracle_keys(oracle_keys) do
      OracleDependencyPlanner.build_plan(requested_oracle_keys, fn oracle_key ->
        with {:ok, module} <- oracle_module(registry, oracle_key),
             {:ok, requires} <- module_requires(oracle_key, module) do
          {:ok, requires}
        end
      end)
    end
  end

  @spec known_consumers(registry()) :: [consumer_key()]
  def known_consumers(registry) do
    case consumers(registry) do
      {:ok, consumers} -> consumers |> Map.keys() |> Enum.sort()
      {:error, _reason} -> []
    end
  end

  defp module_requires(oracle_key, module) do
    with {:module, _loaded_module} <- Code.ensure_loaded(module) do
      case function_exported?(module, :requires, 0) do
        true ->
          case module.requires() do
            requires when is_list(requires) ->
              normalize_oracle_keys(requires, {:requires, oracle_key})

            invalid_requires ->
              {:error,
               {:invalid_dependency_profile,
                {:invalid_requires_declaration, oracle_key, invalid_requires}}}
          end

        false ->
          {:ok, []}
      end
    else
      _ ->
        {:error, {:invalid_dependency_profile, {:oracle_module_not_loaded, oracle_key, module}}}
    end
  end

  defp consumers(registry) do
    case fetch(registry, :consumers) do
      consumers when is_map(consumers) ->
        {:ok, consumers}

      _ ->
        {:error, {:invalid_dependency_profile, {:invalid_registry_field, :consumers}}}
    end
  end

  defp oracle_modules(registry) do
    case fetch(registry, :oracles) do
      oracle_modules when is_map(oracle_modules) ->
        {:ok, oracle_modules}

      _ ->
        {:error, {:invalid_dependency_profile, {:invalid_registry_field, :oracles}}}
    end
  end

  defp fetch_consumer_profile(consumers, consumer_key) do
    case Map.get(consumers, consumer_key) do
      nil -> {:error, {:unknown_consumer, consumer_key}}
      profile -> {:ok, profile}
    end
  end

  defp normalize_profile(profile) when is_map(profile) do
    required_input = fetch(profile, :required) || []
    optional_input = fetch(profile, :optional) || []

    with {:ok, required} <- normalize_oracle_keys(required_input, :required),
         {:ok, optional} <- normalize_oracle_keys(optional_input, :optional),
         :ok <- reject_cross_bucket_duplicates(required, optional) do
      {:ok, %{required: required, optional: optional}}
    end
  end

  defp normalize_profile(profile),
    do: {:error, {:invalid_dependency_profile, {:invalid_profile, profile}}}

  defp reject_cross_bucket_duplicates(required, optional) do
    overlapping_keys =
      required
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(optional))
      |> MapSet.to_list()
      |> Enum.sort()

    case overlapping_keys do
      [] ->
        :ok

      _ ->
        {:error,
         {:invalid_dependency_profile, {:duplicate_oracle_keys_across_buckets, overlapping_keys}}}
    end
  end

  defp normalize_requested_oracle_keys(oracle_keys),
    do: normalize_oracle_keys(oracle_keys, :requested_oracles)

  defp normalize_oracle_keys(oracle_keys, source) when is_list(oracle_keys) do
    with :ok <- validate_oracle_key_types(oracle_keys, source),
         :ok <- validate_no_duplicates(oracle_keys, source) do
      {:ok, Enum.sort(oracle_keys)}
    end
  end

  defp normalize_oracle_keys(oracle_keys, source),
    do: {:error, {:invalid_dependency_profile, {:invalid_oracle_keys, source, oracle_keys}}}

  defp validate_oracle_key_types(oracle_keys, source) do
    invalid_keys = Enum.reject(oracle_keys, &is_atom/1)

    case invalid_keys do
      [] ->
        :ok

      _ ->
        {:error, {:invalid_dependency_profile, {:invalid_oracle_key_types, source, invalid_keys}}}
    end
  end

  defp validate_no_duplicates(oracle_keys, source) do
    duplicate_keys =
      oracle_keys
      |> Enum.frequencies()
      |> Enum.filter(fn {_key, count} -> count > 1 end)
      |> Enum.map(fn {key, _count} -> key end)
      |> Enum.sort()

    case duplicate_keys do
      [] ->
        :ok

      _ ->
        {:error, {:invalid_dependency_profile, {:duplicate_oracle_keys, source, duplicate_keys}}}
    end
  end

  defp fetch(map, key) do
    case Map.get(map, key) do
      nil -> Map.get(map, Atom.to_string(key))
      value -> value
    end
  end

  defp emit_registry_resolve_stop(registry, consumer_key, result, started_at) do
    OracleTelemetry.registry_resolve_stop(
      %{duration_ms: duration_ms(started_at)},
      %{
        dashboard_product: dashboard_product(registry),
        consumer_key: consumer_key,
        outcome: outcome(result),
        error_type: error_type(result),
        event: :resolve
      }
    )
  end

  defp emit_registry_lookup_stop(registry, oracle_key, result, started_at) do
    OracleTelemetry.registry_lookup_stop(
      %{duration_ms: duration_ms(started_at)},
      %{
        dashboard_product: dashboard_product(registry),
        oracle_key: oracle_key,
        outcome: outcome(result),
        error_type: error_type(result),
        event: :lookup
      }
    )
  end

  defp dashboard_product(registry) do
    case fetch(registry, :dashboard_product) do
      nil -> :unknown
      value -> value
    end
  end

  defp duration_ms(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp outcome({:ok, _}), do: :ok
  defp outcome({:error, {error_type, _}}) when is_atom(error_type), do: error_type
  defp outcome({:error, _}), do: :error

  defp error_type({:error, {type, _}}) when is_atom(type), do: type
  defp error_type({:error, _}), do: :unknown
  defp error_type({:ok, _}), do: :none
end

defmodule Oli.Dashboard.OracleRegistry.Validator do
  @moduledoc """
  Validation helpers for oracle registry declaration integrity.

  This module can be invoked during startup or tests to fail fast on invalid
  registry declarations before runtime execution.
  """

  alias Oli.Dashboard.OracleRegistry
  alias Oli.Dashboard.OracleTelemetry

  @type registry :: OracleRegistry.registry()
  @type error :: OracleRegistry.error()

  @spec validate!(registry()) :: :ok | no_return()
  def validate!(registry) do
    case validate(registry) do
      :ok -> :ok
      {:error, reason} -> raise ArgumentError, "invalid oracle registry: #{inspect(reason)}"
    end
  end

  @spec validate_profile!(registry(), OracleRegistry.consumer_key()) :: :ok | no_return()
  def validate_profile!(registry, consumer_key) do
    case validate_profile(registry, consumer_key) do
      :ok ->
        :ok

      {:error, reason} ->
        raise ArgumentError, "invalid oracle profile #{inspect(consumer_key)}: #{inspect(reason)}"
    end
  end

  @spec validate_on_startup!(registry()) :: :ok | no_return()
  def validate_on_startup!(registry), do: validate!(registry)

  @spec validate(registry()) :: :ok | {:error, error()}
  def validate(registry) do
    result =
      with {:ok, consumers} <- fetch_consumers(registry),
           :ok <- validate_oracle_modules(registry),
           :ok <- validate_profiles(registry, consumers),
           :ok <- validate_plans(registry, consumers) do
        :ok
      end

    case result do
      :ok ->
        :ok

      {:error, reason} = error ->
        emit_validation_error(registry, reason, nil)
        error
    end
  end

  @spec validate_profile(registry(), OracleRegistry.consumer_key()) :: :ok | {:error, error()}
  def validate_profile(registry, consumer_key) do
    result =
      with {:ok, profile} <- OracleRegistry.dependencies_for(registry, consumer_key),
           :ok <- validate_declared_oracles(registry, consumer_key, profile),
           :ok <- validate_plan(registry, profile) do
        :ok
      end

    case result do
      :ok ->
        :ok

      {:error, reason} = error ->
        emit_validation_error(registry, reason, consumer_key)
        error
    end
  end

  defp fetch_consumers(registry) do
    case Map.get(registry, :consumers) || Map.get(registry, "consumers") do
      consumers when is_map(consumers) -> {:ok, consumers}
      _ -> {:error, {:invalid_dependency_profile, {:invalid_registry_field, :consumers}}}
    end
  end

  defp fetch_oracles(registry) do
    case Map.get(registry, :oracles) || Map.get(registry, "oracles") do
      oracles when is_map(oracles) -> {:ok, oracles}
      _ -> {:error, {:invalid_dependency_profile, {:invalid_registry_field, :oracles}}}
    end
  end

  defp validate_profiles(registry, consumers) do
    consumers
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce_while(:ok, fn consumer_key, :ok ->
      case validate_profile(registry, consumer_key) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_declared_oracles(registry, consumer_key, %{required: required, optional: optional}) do
    declared_oracles = Enum.uniq(required ++ optional)

    Enum.reduce_while(declared_oracles, :ok, fn oracle_key, :ok ->
      case OracleRegistry.oracle_module(registry, oracle_key) do
        {:ok, _module} ->
          {:cont, :ok}

        {:error, {:unknown_oracle, _missing_oracle}} ->
          {:halt,
           {:error, {:invalid_dependency_profile, {:undeclared_oracle, consumer_key, oracle_key}}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_oracle_modules(registry) do
    with {:ok, oracle_modules} <- fetch_oracles(registry) do
      oracle_modules
      |> Enum.sort_by(fn {oracle_key, _module} -> oracle_key end)
      |> Enum.reduce_while(:ok, fn {oracle_key, module}, :ok ->
        case validate_oracle_module(registry, oracle_key, module) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp validate_oracle_module(registry, oracle_key, module) when is_atom(module) do
    with :ok <- ensure_module_loaded(oracle_key, module),
         :ok <- validate_required_callbacks(oracle_key, module),
         :ok <- validate_key_match(oracle_key, module),
         :ok <- validate_requires_declarations(registry, oracle_key, module) do
      :ok
    end
  end

  defp validate_oracle_module(_registry, oracle_key, invalid_module) do
    {:error, {:invalid_dependency_profile, {:invalid_oracle_module, oracle_key, invalid_module}}}
  end

  defp ensure_module_loaded(oracle_key, module) do
    case Code.ensure_loaded(module) do
      {:module, _loaded_module} ->
        :ok

      _ ->
        {:error, {:invalid_dependency_profile, {:oracle_module_not_loaded, oracle_key, module}}}
    end
  end

  defp validate_required_callbacks(oracle_key, module) do
    required_callbacks = [key: 0, version: 0, load: 2]

    missing_callbacks =
      Enum.reject(required_callbacks, fn {callback_name, callback_arity} ->
        function_exported?(module, callback_name, callback_arity)
      end)

    case missing_callbacks do
      [] ->
        :ok

      _ ->
        {:error,
         {:invalid_dependency_profile,
          {:missing_oracle_callbacks, oracle_key, module, missing_callbacks}}}
    end
  end

  defp validate_key_match(oracle_key, module) do
    case module.key() do
      ^oracle_key ->
        :ok

      declared_key ->
        {:error, {:invalid_dependency_profile, {:oracle_key_mismatch, oracle_key, declared_key}}}
    end
  end

  defp validate_requires_declarations(registry, oracle_key, module) do
    requires =
      case function_exported?(module, :requires, 0) do
        true -> module.requires()
        false -> []
      end

    case requires do
      list when is_list(list) ->
        if oracle_key in list do
          {:error, {:invalid_dependency_profile, {:self_dependency, oracle_key}}}
        else
          validate_required_oracles_declared(registry, oracle_key, list)
        end

      invalid_requires ->
        {:error,
         {:invalid_dependency_profile,
          {:invalid_requires_declaration, oracle_key, invalid_requires}}}
    end
  end

  defp validate_required_oracles_declared(registry, oracle_key, requires) do
    duplicate_keys =
      requires
      |> Enum.frequencies()
      |> Enum.filter(fn {_key, count} -> count > 1 end)
      |> Enum.map(fn {key, _count} -> key end)
      |> Enum.sort()

    case duplicate_keys do
      [] ->
        Enum.reduce_while(requires, :ok, fn required_oracle_key, :ok ->
          case OracleRegistry.oracle_module(registry, required_oracle_key) do
            {:ok, _module} ->
              {:cont, :ok}

            {:error, {:unknown_oracle, _missing_oracle_key}} ->
              {:halt,
               {:error,
                {:invalid_dependency_profile,
                 {:undeclared_oracle, oracle_key, required_oracle_key}}}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        end)

      _ ->
        {:error,
         {:invalid_dependency_profile,
          {:duplicate_oracle_keys, {:requires, oracle_key}, duplicate_keys}}}
    end
  end

  defp validate_plans(registry, consumers) do
    consumers
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce_while(:ok, fn consumer_key, :ok ->
      with {:ok, profile} <- OracleRegistry.dependencies_for(registry, consumer_key),
           :ok <- validate_plan(registry, profile) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_plan(registry, %{required: required, optional: optional}) do
    case OracleRegistry.execution_plan_for(registry, required ++ optional) do
      {:ok, _stages} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp emit_validation_error(registry, reason, consumer_key) do
    OracleTelemetry.registry_validation_error(%{
      dashboard_product: dashboard_product(registry),
      consumer_key: consumer_key,
      outcome: :error,
      error_type: error_type(reason),
      event: :validation
    })
  end

  defp dashboard_product(registry) do
    Map.get(registry, :dashboard_product) || Map.get(registry, "dashboard_product") || :unknown
  end

  defp error_type({type, _}) when is_atom(type), do: type
  defp error_type(type) when is_atom(type), do: type
  defp error_type(_), do: :unknown
end

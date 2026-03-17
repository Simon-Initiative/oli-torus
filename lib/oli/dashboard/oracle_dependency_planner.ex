defmodule Oli.Dashboard.OracleDependencyPlanner do
  @moduledoc """
  Builds deterministic prerequisite-aware oracle execution plans.
  """

  @type oracle_key :: atom()
  @type requires_resolver ::
          (oracle_key() -> {:ok, [oracle_key()]} | {:error, term()})
  @type dependency_graph :: %{optional(oracle_key()) => [oracle_key()]}

  @type error ::
          {:unknown_oracle, oracle_key()}
          | {:invalid_dependency_profile, term()}
          | {:oracle_dependency_cycle, [oracle_key()]}

  @spec build_plan([oracle_key()], requires_resolver()) ::
          {:ok, [[oracle_key()]]} | {:error, error()}
  def build_plan(oracle_keys, requires_resolver)
      when is_list(oracle_keys) and is_function(requires_resolver, 1) do
    with {:ok, normalized_keys} <- normalize_oracle_keys(oracle_keys, :requested_oracles),
         {:ok, graph} <- build_graph(normalized_keys, requires_resolver, %{}),
         :ok <- validate_acyclic(graph) do
      {:ok, to_execution_stages(graph)}
    end
  end

  def build_plan(oracle_keys, _requires_resolver) do
    {:error, {:invalid_dependency_profile, {:invalid_requested_oracles, oracle_keys}}}
  end

  @spec validate_acyclic(dependency_graph()) :: :ok | {:error, error()}
  def validate_acyclic(graph) when is_map(graph) do
    with {:ok, normalized_graph} <- normalize_graph(graph),
         :ok <- assert_no_cycles(normalized_graph) do
      :ok
    end
  end

  def validate_acyclic(graph),
    do: {:error, {:invalid_dependency_profile, {:invalid_dependency_graph, graph}}}

  defp build_graph([], _requires_resolver, graph), do: {:ok, graph}

  defp build_graph([oracle_key | remaining_oracle_keys], requires_resolver, graph) do
    with {:ok, updated_graph} <- ensure_oracle_entry(oracle_key, requires_resolver, graph) do
      build_graph(remaining_oracle_keys, requires_resolver, updated_graph)
    end
  end

  defp ensure_oracle_entry(oracle_key, _requires_resolver, graph)
       when is_map_key(graph, oracle_key),
       do: {:ok, graph}

  defp ensure_oracle_entry(oracle_key, requires_resolver, graph) do
    with {:ok, requires} <- resolve_requires(oracle_key, requires_resolver),
         {:ok, updated_graph} <-
           build_graph(requires, requires_resolver, Map.put(graph, oracle_key, requires)) do
      {:ok, updated_graph}
    end
  end

  defp resolve_requires(oracle_key, requires_resolver) do
    case requires_resolver.(oracle_key) do
      {:ok, requires} ->
        with {:ok, normalized_requires} <-
               normalize_oracle_keys(requires, {:requires, oracle_key}),
             :ok <- reject_self_dependency(oracle_key, normalized_requires) do
          {:ok, normalized_requires}
        end

      {:error, _reason} = error ->
        error

      other ->
        {:error, {:invalid_dependency_profile, {:invalid_requires_result, oracle_key, other}}}
    end
  end

  defp reject_self_dependency(oracle_key, requires) do
    if oracle_key in requires do
      {:error, {:invalid_dependency_profile, {:self_dependency, oracle_key}}}
    else
      :ok
    end
  end

  defp normalize_graph(graph) do
    Enum.reduce_while(graph, {:ok, %{}}, fn {oracle_key, requires}, {:ok, normalized_graph} ->
      with {:ok, [normalized_oracle_key]} <- normalize_oracle_keys([oracle_key], :graph_key),
           {:ok, normalized_requires} <-
             normalize_oracle_keys(requires, {:graph_requires, normalized_oracle_key}),
           :ok <- reject_self_dependency(normalized_oracle_key, normalized_requires) do
        {:cont, {:ok, Map.put(normalized_graph, normalized_oracle_key, normalized_requires)}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized_graph} ->
        case unknown_graph_dependencies(normalized_graph) do
          [] ->
            {:ok, normalized_graph}

          unknown_oracles ->
            {:error, {:invalid_dependency_profile, {:undeclared_oracles, unknown_oracles}}}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp unknown_graph_dependencies(graph) do
    known_oracles = Map.keys(graph) |> MapSet.new()

    graph
    |> Map.values()
    |> List.flatten()
    |> MapSet.new()
    |> MapSet.difference(known_oracles)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp assert_no_cycles(graph) do
    Enum.reduce_while(
      Map.keys(graph) |> Enum.sort(),
      {:ok, %{state: %{}, stack: []}},
      fn oracle_key, {:ok, traversal} ->
        case dfs(oracle_key, graph, traversal) do
          {:ok, updated_traversal} -> {:cont, {:ok, updated_traversal}}
          {:error, _reason} = error -> {:halt, error}
        end
      end
    )
    |> case do
      {:ok, _traversal} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp dfs(oracle_key, graph, %{state: state} = traversal) do
    case Map.get(state, oracle_key) do
      :visited ->
        {:ok, traversal}

      :visiting ->
        {:error, {:oracle_dependency_cycle, cycle_keys(oracle_key, traversal.stack)}}

      nil ->
        next_traversal = %{
          traversal
          | state: Map.put(state, oracle_key, :visiting),
            stack: [oracle_key | traversal.stack]
        }

        Enum.reduce_while(
          Map.get(graph, oracle_key, []),
          {:ok, next_traversal},
          fn dependency_key, {:ok, current_traversal} ->
            case dfs(dependency_key, graph, current_traversal) do
              {:ok, updated_traversal} -> {:cont, {:ok, updated_traversal}}
              {:error, _reason} = error -> {:halt, error}
            end
          end
        )
        |> case do
          {:ok, updated_traversal} ->
            {:ok,
             %{
               updated_traversal
               | state: Map.put(updated_traversal.state, oracle_key, :visited),
                 stack: tl(updated_traversal.stack)
             }}

          {:error, _reason} = error ->
            error
        end
    end
  end

  defp cycle_keys(oracle_key, stack) do
    stack
    |> Enum.take_while(&(&1 != oracle_key))
    |> then(&Enum.reverse([oracle_key | &1]))
  end

  defp to_execution_stages(graph) do
    graph
    |> Enum.map(fn {oracle_key, requires} -> {oracle_key, MapSet.new(requires)} end)
    |> Map.new()
    |> collect_execution_stages([])
  end

  defp collect_execution_stages(remaining_oracles, stages)
       when map_size(remaining_oracles) == 0 do
    Enum.reverse(stages)
  end

  defp collect_execution_stages(remaining_oracles, stages) do
    stage =
      remaining_oracles
      |> Enum.filter(fn {_oracle_key, dependencies} -> MapSet.size(dependencies) == 0 end)
      |> Enum.map(fn {oracle_key, _dependencies} -> oracle_key end)
      |> Enum.sort()

    case stage do
      [] ->
        # Safety fallback; cycle detection should have already produced a typed error.
        Enum.reverse(stages)

      _ ->
        stage_key_set = MapSet.new(stage)

        next_remaining_oracles =
          remaining_oracles
          |> Enum.reject(fn {oracle_key, _dependencies} -> oracle_key in stage end)
          |> Enum.map(fn {oracle_key, dependencies} ->
            {oracle_key, MapSet.difference(dependencies, stage_key_set)}
          end)
          |> Map.new()

        collect_execution_stages(next_remaining_oracles, [stage | stages])
    end
  end

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
end

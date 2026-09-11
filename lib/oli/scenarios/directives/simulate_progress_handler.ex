defmodule Oli.Scenarios.Directives.SimulateProgressHandler do
  @moduledoc "Executes the simulate_progress scenario directive."

  alias Oli.Scenarios.DirectiveTypes.SimulateProgressDirective
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.ProgressSimulation

  def handle(%SimulateProgressDirective{} = directive, state) do
    with section when not is_nil(section) <- Engine.get_section(state, directive.section),
         {:ok, users} <- resolve_users(directive.users, state),
         {:ok, result} <- ProgressSimulation.run(section, users, Map.from_struct(directive)) do
      {:ok,
       state
       |> Map.update!(:scenario_results, &Map.put(&1, :simulate_progress, result))
       |> Map.update!(:scenario_warnings, &bounded_warnings(&1, result.warnings))}
    else
      nil -> {:error, "Section '#{directive.section}' not found"}
      {:error, reason} -> {:error, "simulate_progress failed: #{inspect(reason)}"}
    end
  end

  defp resolve_users(nil, _state), do: {:ok, nil}

  defp resolve_users(names, state) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, users} ->
      case Engine.get_user(state, name) do
        nil -> {:halt, {:error, "User '#{name}' not found"}}
        user -> {:cont, {:ok, [user | users]}}
      end
    end)
    |> case do
      {:ok, users} -> {:ok, Enum.reverse(users)}
      error -> error
    end
  end

  defp bounded_warnings(existing, new), do: Enum.take(existing ++ new, 100)
end

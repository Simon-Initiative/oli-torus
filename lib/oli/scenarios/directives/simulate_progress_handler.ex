defmodule Oli.Scenarios.Directives.SimulateProgressHandler do
  @moduledoc "Executes the simulate_progress scenario directive."

  alias Oli.Scenarios.DirectiveTypes.SimulateProgressDirective
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.ProgressSimulation

  def handle(%SimulateProgressDirective{} = directive, state) do
    with section when not is_nil(section) <- Engine.get_section(state, directive.section),
         {:ok, users} <- resolve_users(directive.users, state),
         :ok <- validate_scenario_time(directive.timing, state.scenario_time),
         opts <- Map.from_struct(directive),
         {:ok, result} <- ProgressSimulation.run(section, users, opts) do
      {:ok,
       state
       |> Map.update!(:scenario_results, &Map.put(&1, :simulate_progress, result))
       |> Map.update!(:scenario_warnings, &bounded_warnings(&1, result.warnings))}
    else
      nil ->
        {:error, "Section '#{directive.section}' not found"}

      {:error, reason, result} ->
        updated_state =
          state
          |> Map.update!(:scenario_results, &Map.put(&1, :simulate_progress, result))
          |> Map.update!(:scenario_warnings, &bounded_warnings(&1, result.warnings))

        {:error, "simulate_progress failed: #{inspect(reason)}", updated_state}

      {:error, reason} ->
        {:error, "simulate_progress failed: #{inspect(reason)}"}
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

  defp validate_scenario_time(:paced, scenario_time) when not is_nil(scenario_time),
    do: {:error, "paced mode cannot run while a scenario time override is active"}

  defp validate_scenario_time(_timing, _scenario_time), do: :ok

  defp bounded_warnings(existing, new), do: Enum.take(existing ++ new, 100)
end

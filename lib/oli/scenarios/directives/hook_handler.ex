defmodule Oli.Scenarios.Directives.HookHandler do
  @moduledoc """
  Handles hook directives that execute custom Elixir functions.

  Hook directives provide a powerful extension mechanism for scenarios,
  allowing injection of custom logic, data manipulation, or any other
  operations that might not be covered by standard directives.
  """

  alias Oli.Scenarios.DirectiveTypes.{HookDirective, ExecutionState}

  @doc """
  Executes a hook directive by calling the specified function with the current state.

  The function string should be in the format "Module.function/arity",
  e.g., "Oli.Scenarios.Hooks.inject_bad_data/1"

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%HookDirective{function: function_spec}, %ExecutionState{} = state) do
    case parse_and_execute(function_spec, state) do
      {:ok, new_state} when is_struct(new_state, ExecutionState) ->
        {:ok, new_state}

      {:ok, result} ->
        {:error, "Hook function must return an ExecutionState, got: #{inspect(result)}"}

      {:error, reason} ->
        {:error, "Hook execution failed: #{reason}"}
    end
  end

  defp parse_and_execute(function_spec, state) do
    try do
      # Parse the function specification
      case parse_function_spec(function_spec) do
        {:ok, module, function_name, arity} ->
          # Verify arity is 1 (function must accept ExecutionState)
          if arity != 1 do
            {:error, "Hook function must have arity 1, got #{arity}"}
          else
            # Ensure module is loaded
            ensure_module_loaded(module)

            # Check if function exists
            if function_exported?(module, function_name, 1) do
              # Execute the function
              result = apply(module, function_name, [state])
              {:ok, result}
            else
              {:error, "Function #{module}.#{function_name}/1 not found"}
            end
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        {:error, "Error executing hook: #{Exception.message(e)}"}
    end
  end

  defp parse_function_spec(spec) when is_binary(spec) do
    # Expected format: "Module.Path.function/arity"
    case Regex.run(~r/^(.+)\.([^\/]+)\/(\d+)$/, spec) do
      [_, module_path, function_name, arity_str] ->
        # Validate module is in allowed namespace for security
        unless String.starts_with?(module_path, "Oli.Scenarios.") do
          raise "Hook module must be in Oli.Scenarios namespace for security. Got: #{module_path}"
        end

        # Convert module path to atom safely
        module =
          try do
            String.to_existing_atom("Elixir.#{module_path}")
          rescue
            ArgumentError ->
              # Module not loaded yet, but validated to be in safe namespace
              String.to_atom("Elixir.#{module_path}")
          end

        # Function names are less risky as atoms since they're limited in scope
        function_name = String.to_atom(function_name)
        {arity, _} = Integer.parse(arity_str)

        {:ok, module, function_name, arity}

      _ ->
        {:error,
         "Invalid function specification format. Expected 'Module.function/arity', got: #{spec}"}
    end
  end

  defp parse_function_spec(_), do: {:error, "Function specification must be a string"}

  defp ensure_module_loaded(module) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        :ok

      {:error, _reason} ->
        # Try to compile from test/scenarios directory
        module_path = module_to_path(module)

        case compile_from_scenarios(module_path) do
          :ok ->
            :ok

          {:error, compile_reason} ->
            raise "Failed to load module #{module}: Module not loaded and could not compile from #{module_path}: #{compile_reason}"
        end
    end
  end

  defp module_to_path(module) do
    # Module.split returns ["Oli", "Scenarios", "Activities", "NullLogicHooks"]
    # We want "activities/null_logic_hooks.ex"
    parts = Module.split(module)

    case parts do
      ["Oli", "Scenarios" | rest] ->
        rest
        |> Enum.map(&Macro.underscore/1)
        |> Path.join()
        |> Kernel.<>(".ex")

      _ ->
        # Fallback for other module patterns
        parts
        |> Enum.map(&Macro.underscore/1)
        |> Path.join()
        |> Kernel.<>(".ex")
    end
  end

  defp compile_from_scenarios(relative_path) do
    # Try multiple possible locations
    possible_paths = [
      Path.join(["test", "scenarios", relative_path]),
      Path.join(["test", "support", "scenarios", relative_path]),
      Path.join(["lib", "oli", "scenarios", relative_path])
    ]

    Enum.find_value(
      possible_paths,
      {:error, "File not found in any expected location"},
      fn path ->
        if File.exists?(path) do
          case Code.compile_file(path) do
            [{_module, _binary}] -> :ok
            _ -> {:error, "Failed to compile #{path}"}
          end
        else
          false
        end
      end
    )
  end
end

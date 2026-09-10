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

  defp parse_and_execute(function_spec, %ExecutionState{} = state) do
    existing_atoms_only? = state.ownership

    try do
      # Parse the function specification
      case parse_function_spec(function_spec, existing_atoms_only?) do
        {:ok, module, function_name_string, arity} ->
          # Verify arity is 1 (function must accept ExecutionState)
          if arity != 1 do
            {:error, "Hook function must have arity 1, got #{arity}"}
          else
            # Ensure module is loaded and, if necessary, refreshed from disk
            ensure_module_loaded(module)

            with {:ok, function_name} <- safe_atom(function_name_string, existing_atoms_only?),
                 :ok <- ensure_function_loaded(module, function_name, 1) do
              result = apply(module, function_name, [state])
              {:ok, result}
            else
              {:error, reason} -> {:error, reason}
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

  defp parse_function_spec(spec, existing_atoms_only?) when is_binary(spec) do
    # Expected format: "Module.Path.function/arity"
    case Regex.run(~r/^(.+)\.([^\/]+)\/(\d+)$/, spec) do
      [_, module_path, function_name, arity_str] ->
        # Validate module is in allowed namespace for security
        unless String.starts_with?(module_path, "Oli.Scenarios.") do
          raise "Hook module must be in Oli.Scenarios namespace for security. Got: #{module_path}"
        end

        # Convert module path to atom safely
        with {:ok, module} <- safe_atom("Elixir.#{module_path}", existing_atoms_only?) do
          {arity, _} = Integer.parse(arity_str)
          {:ok, module, function_name, arity}
        end

      _ ->
        {:error,
         "Invalid function specification format. Expected 'Module.function/arity', got: #{spec}"}
    end
  end

  defp parse_function_spec(_, _), do: {:error, "Function specification must be a string"}

  defp safe_atom(value, true) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> {:error, "Hook module and function must already be compiled"}
    end
  end

  defp safe_atom(value, false), do: {:ok, String.to_atom(value)}

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

  defp ensure_function_loaded(module, function_name, arity) do
    if function_exported?(module, function_name, arity) do
      :ok
    else
      # Long-lived scenario runners may keep an older version of a hook module loaded.
      module
      |> module_to_path()
      |> compile_from_scenarios()

      if function_exported?(module, function_name, arity) do
        :ok
      else
        {:error, "Function #{module}.#{function_name}/#{arity} not found"}
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

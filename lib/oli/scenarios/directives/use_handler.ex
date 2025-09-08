defmodule Oli.Scenarios.Directives.UseHandler do
  @moduledoc """
  Handles the 'use' directive which includes and executes another YAML scenario file
  within the current execution context.
  """

  alias Oli.Scenarios.DirectiveTypes.{UseDirective, ExecutionState}

  @doc """
  Processes a use directive to include and execute another YAML file.
  The included file shares the same execution context as the parent file.
  """
  def handle(%UseDirective{file: file}, %ExecutionState{} = state) when is_binary(file) do
    # Get the current file path from state if available, otherwise use current directory
    current_dir = Map.get(state, :current_dir, ".")

    # Resolve the relative path
    resolved_path = Path.join(current_dir, file)
    resolved_path = Path.expand(resolved_path)

    # Check if file exists
    unless File.exists?(resolved_path) do
      raise "Use directive failed: File not found: #{resolved_path}"
    end

    # Track include stack for better error messages
    include_stack = Map.get(state, :include_stack, [])

    # Check for circular includes
    if resolved_path in include_stack do
      raise "Circular include detected: #{resolved_path} is already in include stack: #{inspect(include_stack)}"
    end

    # Update the current directory and include stack in state
    new_dir = Path.dirname(resolved_path)

    state_with_context =
      state
      |> Map.put(:current_dir, new_dir)
      |> Map.put(:include_stack, [resolved_path | include_stack])

    # Load and parse the included file
    directives = Oli.Scenarios.DirectiveParser.load_file!(resolved_path)

    # Execute the directives from the included file in the current state
    # We need to execute them one by one and accumulate state changes
    result =
      Enum.reduce_while(directives, {:ok, state_with_context}, fn directive, {:ok, acc_state} ->
        # Import the Engine module to access execute_directive
        case execute_directive(directive, acc_state) do
          {:ok, new_state} ->
            {:cont, {:ok, new_state}}

          {:ok, new_state, _verification} ->
            {:cont, {:ok, new_state}}

          {:error, _reason} = error ->
            {:halt, error}
        end
      end)

    # Restore the original directory and include stack in the state
    case result do
      {:ok, final_state} ->
        {:ok,
         final_state
         |> Map.put(:current_dir, current_dir)
         |> Map.put(:include_stack, include_stack)}

      error ->
        error
    end
  end

  def handle(%UseDirective{file: nil}, _state) do
    {:error, "Use directive requires a 'file' parameter"}
  end

  # Helper function to execute a directive - delegates to Engine
  defp execute_directive(directive, state) do
    # We need to call back into the Engine to execute directives
    # This creates a circular dependency, so we'll use apply/3
    apply(Oli.Scenarios.Engine, :execute_directive, [directive, state])
  end
end

defmodule Oli.Scenarios.Directives.ManipulateHandler do
  @moduledoc """
  Handler for manipulate directives that apply operations to projects.
  """
  
  alias Oli.Scenarios.DirectiveTypes.{ManipulateDirective, ExecutionState}
  alias Oli.Scenarios.Ops
  
  def handle(%ManipulateDirective{target: target, ops: ops}, %ExecutionState{} = state) do
    case Map.get(state.projects, target) do
      nil ->
        {:error, "Project '#{target}' not found", state}
        
      built_project ->
        # Apply operations
        try do
          {_major?, updated_project} = Ops.apply_ops!(built_project, ops)
          
          # Update state with modified project
          updated_state = %{state | 
            projects: Map.put(state.projects, target, updated_project)
          }
          
          {:ok, updated_state}
        rescue
          e ->
            {:error, "Failed to apply operations: #{inspect(e)}", state}
        end
    end
  end
end
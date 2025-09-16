defmodule Oli.Scenarios.Directives.ManipulateHandler do
  @moduledoc """
  Handler for manipulate directives that apply operations to projects, sections, or products.
  """

  alias Oli.Scenarios.DirectiveTypes.{ManipulateDirective, ExecutionState}
  alias Oli.Scenarios.{Ops, Engine, SectionOps}

  def handle(%ManipulateDirective{to: to, ops: ops}, %ExecutionState{} = state) do
    # Check if it's a project, product, or section
    cond do
      # Check for project
      built_project = Map.get(state.projects, to) ->
        # Apply operations to project
        try do
          {_major?, updated_project} = Ops.apply_ops!(built_project, ops)

          # Update state with modified project
          updated_state = %{state | projects: Map.put(state.projects, to, updated_project)}

          {:ok, updated_state}
        rescue
          e ->
            {:error, "Failed to apply operations to project: #{inspect(e)}"}
        end

      # Check for product
      product = Engine.get_product(state, to) ->
        # Apply operations to product (treated as section)
        try do
          updated_product = SectionOps.apply_ops!(product, ops)

          # Update state with modified product
          updated_state = Engine.put_product(state, to, updated_product)

          {:ok, updated_state}
        rescue
          e ->
            {:error, "Failed to apply operations to product: #{inspect(e)}"}
        end

      # Check for section
      section = Engine.get_section(state, to) ->
        # Apply operations to section
        try do
          updated_section = SectionOps.apply_ops!(section, ops)

          # Update state with modified section
          updated_state = Engine.put_section(state, to, updated_section)

          {:ok, updated_state}
        rescue
          e ->
            {:error, "Failed to apply operations to section: #{inspect(e)}"}
        end

      true ->
        {:error, "Target '#{to}' not found as project, section, or product"}
    end
  end
end

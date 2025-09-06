defmodule Oli.Scenarios.Directives.AssertHandler do
  @moduledoc """
  Main handler for assert directives that delegates to specific assertion types.
  """

  alias Oli.Scenarios.DirectiveTypes.AssertDirective
  alias Oli.Scenarios.Directives.Assert.{
    StructureAssertion,
    ResourceAssertion,
    ProgressAssertion,
    GeneralAssertion
  }

  @doc """
  Handles an assert directive by delegating to the appropriate assertion module.
  
  The assert directive can perform different types of assertions:
  - structure: Verify the hierarchical structure of a project or section
  - resource: Verify properties of a specific resource
  - progress: Verify student progress in a page or container
  - assertions: General assertions (legacy support)
  """
  def handle(%AssertDirective{} = directive, state) do
    # Try each assertion type until one is found
    cond do
      directive.progress != nil ->
        ProgressAssertion.assert(directive, state)
      
      directive.structure != nil ->
        StructureAssertion.assert(directive, state)
      
      directive.resource != nil ->
        ResourceAssertion.assert(directive, state)
      
      directive.assertions != nil ->
        GeneralAssertion.assert(directive, state)
      
      true ->
        {:error, "Assert directive must specify at least one assertion type"}
    end
  end
end
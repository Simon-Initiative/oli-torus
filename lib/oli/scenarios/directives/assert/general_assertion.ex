defmodule Oli.Scenarios.Directives.Assert.GeneralAssertion do
  @moduledoc """
  Handles general assertions (legacy support).
  """

  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}

  @doc """
  Performs general assertions based on the assertions list.
  Currently a placeholder for potential future general assertion support.
  """
  def assert(%AssertDirective{assertions: assertions}, state) when is_list(assertions) do
    # For now, just note that assertions were specified
    # This could be expanded in the future to integrate with a more general assertions framework
    
    verification_result = %VerificationResult{
      to: nil,
      passed: true,
      message: "General assertions (#{length(assertions)} specified) - not yet implemented"
    }
    
    {:ok, state, verification_result}
  end
  
  def assert(%AssertDirective{assertions: nil}, state), do: {:ok, state, nil}
end
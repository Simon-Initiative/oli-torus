defmodule Oli.Help.Dispatcher do
  alias Oli.Help.HelpContent

  @doc """
  Dispatches help requests to help support (email or some other form of helpdesk).
  """
  @callback dispatch(%HelpContent{}) :: {:ok, term} | {:error, String.t()}

  def dispatch(implementation, %HelpContent{} = contents) do
    implementation.dispatch(contents)
  end
end

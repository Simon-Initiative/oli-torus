defmodule Oli.Help.Dispatcher do

  alias Oli.Help.HelpContent

  @doc """
  Dispatches help requests to help support (email or some other form of helpdesk).
  """
  @callback dispatch(%HelpContent{}) :: {:ok, term} | {:error, String.t}

  def dispatch!(implementation, %HelpContent{} = contents) do
    case implementation.dispatch(contents) do
      {:ok, data} -> data
      {:error, error} -> raise ArgumentError, "dispatch error: #{error}"
    end
  end

end

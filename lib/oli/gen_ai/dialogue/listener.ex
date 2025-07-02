defmodule Oli.GenAI.Dialogue.Listener do

  @callback tokens_received(String.t()) :: any()
  @callback complete() :: any()

end

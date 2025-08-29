defmodule Oli.GenAI.Agent.LoopDetector do
  @moduledoc """
  Behavior for implementing different loop detection strategies.
  """

  @doc """
  Detects if the given steps indicate a loop pattern.
  """
  @callback detect(steps :: list()) :: boolean()
end

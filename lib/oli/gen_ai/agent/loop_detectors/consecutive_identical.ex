defmodule Oli.GenAI.Agent.LoopDetectors.ConsecutiveIdentical do
  @moduledoc """
  Detects loops where the same action is repeated consecutively.
  """
  @behaviour Oli.GenAI.Agent.LoopDetector

  alias Oli.GenAI.Agent.ActionComparator

  @impl true
  def detect(steps) when is_list(steps) do
    steps
    # Check last 4 steps
    |> Enum.take(4)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [step1, step2] ->
      ActionComparator.identical?(
        Map.get(step1, :action),
        Map.get(step2, :action)
      )
    end)
  end

  def detect(_), do: false
end

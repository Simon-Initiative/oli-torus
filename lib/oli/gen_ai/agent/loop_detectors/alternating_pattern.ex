defmodule Oli.GenAI.Agent.LoopDetectors.AlternatingPattern do
  @moduledoc """
  Detects alternating pattern loops (A -> B -> A -> B).
  """
  @behaviour Oli.GenAI.Agent.LoopDetector

  alias Oli.GenAI.Agent.ActionComparator

  @impl true
  def detect(steps) when is_list(steps) do
    case Enum.take(steps, 4) do
      [s1, s2, s3, s4] ->
        ActionComparator.identical?(
          Map.get(s1, :action),
          Map.get(s3, :action)
        ) and
          ActionComparator.identical?(
            Map.get(s2, :action),
            Map.get(s4, :action)
          ) and
          not ActionComparator.identical?(
            Map.get(s1, :action),
            Map.get(s2, :action)
          )

      _ ->
        false
    end
  end

  def detect(_), do: false
end

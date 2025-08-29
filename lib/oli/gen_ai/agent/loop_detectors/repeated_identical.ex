defmodule Oli.GenAI.Agent.LoopDetectors.RepeatedIdentical do
  @moduledoc """
  Detects when the same tool is called multiple times with identical arguments.
  """
  @behaviour Oli.GenAI.Agent.LoopDetector

  alias Oli.GenAI.Agent.ActionComparator

  @min_repetitions 3

  @impl true
  def detect(steps) when is_list(steps) do
    tool_calls =
      steps
      |> Enum.take(6)
      |> Enum.filter(&is_tool_action?/1)
      |> Enum.map(fn step -> Map.get(step, :action) end)

    if length(tool_calls) >= @min_repetitions do
      tool_calls
      |> Enum.frequencies_by(&ActionComparator.normalize/1)
      |> Enum.any?(fn {_action, count} -> count >= @min_repetitions end)
    else
      false
    end
  end

  def detect(_), do: false

  defp is_tool_action?(%{action: %{type: "tool"}}), do: true
  defp is_tool_action?(_), do: false
end

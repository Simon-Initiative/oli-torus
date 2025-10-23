defmodule Oli.GenAI.Agent.Critic do
  @moduledoc """
  Provides loop detection, state analysis, and replanning recommendations for agents.

  This module analyzes agent execution patterns to detect problematic behaviors
  like infinite loops, excessive failures, or inefficient execution paths.
  """

  alias Oli.GenAI.Agent.LoopDetectors.{
    ConsecutiveIdentical,
    AlternatingPattern,
    RepeatedIdentical
  }

  alias Oli.GenAI.Agent.StateAnalyzer

  # Configuration constants
  @min_steps_for_loop_detection 6
  @max_recent_failures 3
  @max_steps_before_concern 20
  @plan_complexity_multiplier 2
  @recent_steps_window 5

  # Loop detectors to apply
  @loop_detectors [
    ConsecutiveIdentical,
    AlternatingPattern,
    RepeatedIdentical
  ]

  @type step :: map()
  @type state :: map()

  @doc """
  Detects if the agent is stuck in a loop based on recent step patterns.

  Returns true if any loop detector identifies a problematic pattern.
  Requires at least #{@min_steps_for_loop_detection} steps for meaningful detection.
  """
  @spec looping?(steps :: [step()]) :: boolean()
  def looping?(steps) when is_list(steps) and length(steps) >= @min_steps_for_loop_detection do
    Enum.any?(@loop_detectors, & &1.detect(steps))
  end

  def looping?(_), do: false

  @doc """
  Determines if the agent should replan based on current state.

  Triggers replanning when:
  - Loop detected
  - Too many recent failures (>= #{@max_recent_failures})
  - Execution exceeds planned complexity
  """
  @spec should_replan?(state()) :: boolean()
  def should_replan?(%{steps: steps} = state)
      when length(steps) >= @min_steps_for_loop_detection do
    looping?(steps) or
      too_many_failures?(steps) or
      exceeds_plan_complexity?(state)
  end

  def should_replan?(_), do: false

  @doc """
  Provides a human-readable critique of the current execution state.

  Returns a string describing any issues detected or "Progress appears normal".
  """
  @spec critique(state()) :: String.t()
  def critique(state) do
    state
    |> collect_issues()
    |> format_critique()
  end

  @doc """
  Performs comprehensive state analysis.

  Returns a structured analysis including health status, issues, and recommendations.
  Delegates to StateAnalyzer for detailed analysis.
  """
  @spec analyze(state()) :: StateAnalyzer.analysis()
  defdelegate analyze(state), to: StateAnalyzer

  @doc """
  Counts the number of failures in recent steps.

  Used by StateAnalyzer and other modules for failure rate analysis.
  """
  @spec count_recent_failures([step()]) :: non_neg_integer()
  def count_recent_failures(steps) do
    steps
    |> Enum.take(@recent_steps_window)
    |> Enum.count(&is_failure?/1)
  end

  # Private functions

  @spec collect_issues(state()) :: [String.t()]
  defp collect_issues(state) do
    steps = Map.get(state, :steps, [])

    []
    |> maybe_add_loop_issue(steps)
    |> maybe_add_failure_issue(steps)
    |> maybe_add_complexity_issue(steps)
  end

  @spec maybe_add_loop_issue([String.t()], [step()]) :: [String.t()]
  defp maybe_add_loop_issue(issues, steps) do
    if looping?(steps) do
      ["Appears to be stuck in a loop of repetitive actions" | issues]
    else
      issues
    end
  end

  @spec maybe_add_failure_issue([String.t()], [step()]) :: [String.t()]
  defp maybe_add_failure_issue(issues, steps) do
    failure_count = count_recent_failures(steps)

    if failure_count >= 2 do
      ["Multiple recent tool failures suggest approach may need adjustment" | issues]
    else
      issues
    end
  end

  @spec maybe_add_complexity_issue([String.t()], [step()]) :: [String.t()]
  defp maybe_add_complexity_issue(issues, steps) do
    if length(steps) > @max_steps_before_concern do
      ["Taking many steps - consider if goal is too broad or approach inefficient" | issues]
    else
      issues
    end
  end

  @spec format_critique([String.t()]) :: String.t()
  defp format_critique([]), do: "Progress appears normal"
  defp format_critique(issues), do: "Issues detected: " <> Enum.join(issues, "; ")

  @spec too_many_failures?([step()]) :: boolean()
  defp too_many_failures?(steps) do
    count_recent_failures(steps) >= @max_recent_failures
  end

  @spec exceeds_plan_complexity?(state()) :: boolean()
  defp exceeds_plan_complexity?(state) do
    steps_completed = length(Map.get(state, :steps, []))
    plan_size = length(Map.get(state, :plan, []))

    plan_size > 0 and steps_completed > plan_size * @plan_complexity_multiplier
  end

  @spec is_failure?(step()) :: boolean()
  defp is_failure?(%{observation: %{error: _}}), do: true

  defp is_failure?(%{observation: observation}) when is_binary(observation) do
    String.contains?(observation, "error") or String.contains?(observation, "failed")
  end

  defp is_failure?(_), do: false
end

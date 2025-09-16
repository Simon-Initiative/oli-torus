defmodule Oli.GenAI.Agent.StateAnalyzer do
  @moduledoc """
  Analyzes agent state to determine health and provide recommendations.
  """

  alias Oli.GenAI.Agent.Critic

  @type health :: :normal | :degraded | :critical
  @type recommendation :: :continue | :replan | :abort
  @type issue :: String.t()

  @type analysis :: %{
          health: health(),
          issues: [issue()],
          recommendation: recommendation()
        }

  @doc """
  Analyzes the current state of an agent and provides health assessment and recommendations.
  """
  @spec analyze(map()) :: analysis()
  def analyze(state) do
    issues = collect_issues(state)
    health = determine_health(issues, state)
    recommendation = determine_recommendation(health, state)

    %{
      health: health,
      issues: issues,
      recommendation: recommendation
    }
  end

  @spec collect_issues(map()) :: [issue()]
  defp collect_issues(state) do
    steps = Map.get(state, :steps, [])

    []
    |> maybe_add_loop_issue(steps)
    |> maybe_add_failure_issue(steps)
    |> maybe_add_complexity_issue(steps)
    |> maybe_add_plan_deviation_issue(state)
  end

  @spec maybe_add_loop_issue([issue()], list()) :: [issue()]
  defp maybe_add_loop_issue(issues, steps) do
    if Critic.looping?(steps) do
      ["Detected looping behavior in recent actions" | issues]
    else
      issues
    end
  end

  @spec maybe_add_failure_issue([issue()], list()) :: [issue()]
  defp maybe_add_failure_issue(issues, steps) do
    failure_count = Critic.count_recent_failures(steps)

    cond do
      failure_count >= 3 ->
        ["High failure rate (#{failure_count} failures in recent steps)" | issues]

      failure_count >= 2 ->
        ["Multiple recent failures detected" | issues]

      true ->
        issues
    end
  end

  @spec maybe_add_complexity_issue([issue()], list()) :: [issue()]
  defp maybe_add_complexity_issue(issues, steps) do
    step_count = length(steps)

    cond do
      step_count > 30 ->
        ["Excessive steps taken (#{step_count}), task may be too complex" | issues]

      step_count > 20 ->
        ["Many steps taken (#{step_count}), consider if approach is efficient" | issues]

      true ->
        issues
    end
  end

  @spec maybe_add_plan_deviation_issue([issue()], map()) :: [issue()]
  defp maybe_add_plan_deviation_issue(issues, state) do
    steps_taken = length(Map.get(state, :steps, []))
    plan_size = length(Map.get(state, :plan, []))

    if plan_size > 0 and steps_taken > plan_size * 2 do
      [
        "Significant deviation from original plan (#{steps_taken} steps vs #{plan_size} planned)"
        | issues
      ]
    else
      issues
    end
  end

  @spec determine_health([issue()], map()) :: health()
  defp determine_health(issues, state) do
    steps = Map.get(state, :steps, [])
    issue_count = length(issues)
    failure_count = Critic.count_recent_failures(steps)

    cond do
      Critic.looping?(steps) ->
        :critical

      failure_count >= 3 ->
        :critical

      issue_count >= 3 ->
        :critical

      issue_count >= 1 ->
        :degraded

      true ->
        :normal
    end
  end

  @spec determine_recommendation(health(), map()) :: recommendation()
  defp determine_recommendation(:critical, state) do
    steps = Map.get(state, :steps, [])

    if Critic.looping?(steps) do
      :abort
    else
      :replan
    end
  end

  defp determine_recommendation(:degraded, state) do
    if Critic.should_replan?(state) do
      :replan
    else
      :continue
    end
  end

  defp determine_recommendation(:normal, _state) do
    :continue
  end
end

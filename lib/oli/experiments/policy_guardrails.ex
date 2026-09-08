defmodule Oli.Experiments.PolicyGuardrails do
  @moduledoc """
  Applies experiment-wide allocation guardrails to assignment candidates.
  """

  @doc false
  def fixed_control_condition(_conditions, _assignment_counts, nil), do: nil

  def fixed_control_condition(conditions, assignment_counts, fixed_control_allocation) do
    total = Enum.reduce(assignment_counts, 0, fn {_id, count}, total -> total + count end)
    control = List.first(conditions)
    control_count = Map.get(assignment_counts, control.id, 0)

    cond do
      total == 0 -> control
      control_count / total < fixed_control_allocation -> control
      true -> nil
    end
  end

  @doc false
  def cap_eligible_conditions(conditions, assignment_counts, max_condition_share) do
    total = Enum.reduce(assignment_counts, 0, fn {_id, count}, total -> total + count end)

    eligible =
      Enum.filter(conditions, fn condition ->
        total == 0 or Map.get(assignment_counts, condition.id, 0) / total < max_condition_share
      end)

    case eligible do
      [] -> conditions
      _eligible -> eligible
    end
  end
end

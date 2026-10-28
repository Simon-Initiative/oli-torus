defmodule Oli.Delivery.Metrics.StudentDistributionGroup do
  @moduledoc """
  Classifies enrolled students into the Student Distribution matrix groups used by the
  instructor's expanded Learning Objective visualization: `:needs_support`, `:excelling`, or
  `:limited_activity`.

  Group membership is derived from two independent axes, each split at 50%:

    * numeric learning proficiency (0.0-1.0)
    * activity completion (0.0-1.0)

  This is a distinct axis from the Low/Medium/High proficiency *label* thresholds used for
  chip presentation in `OliWeb.Delivery.LearningObjectives.Proficiency` (Low <= 40%, Medium
  <= 80%, High > 80%). Both thresholds are real and intentionally different: the label is a
  display concern, the 50% split here is the group-membership business rule.

  This module is the single source of truth for group assignment. Both the Student
  Distribution matrix and the group-based student table must read `:distribution_group` from
  here rather than recomputing it, so the two surfaces can never disagree.
  """

  @type group :: :needs_support | :excelling | :limited_activity

  @high_activity_threshold 0.5
  @high_proficiency_threshold 0.5

  @doc """
  Classifies a single student into exactly one distribution group.

  Activity completion below 50% always resolves to `:limited_activity`, regardless of
  proficiency. Above that line, proficiency at or above 50% is `:excelling`; anything else
  (including a `nil` or missing proficiency estimate) is `:needs_support`. Upstream data
  already represents "Not enough data" proficiency as `0.0`
  (`Oli.Delivery.Metrics.student_proficiency_for_objective/2` and the missing-student
  backfill in `ExpandedObjectiveView`), so that case naturally falls into `:needs_support`
  under high activity through this same general rule -- it is not a special-cased branch.
  """
  @spec group_for(proficiency_score :: number() | nil, activity_completion :: number()) ::
          group()
  def group_for(_proficiency_score, activity_completion)
      when is_number(activity_completion) and activity_completion < @high_activity_threshold do
    :limited_activity
  end

  def group_for(proficiency_score, _activity_completion)
      when is_number(proficiency_score) and proficiency_score >= @high_proficiency_threshold do
    :excelling
  end

  def group_for(_proficiency_score, _activity_completion), do: :needs_support

  @doc """
  Adds `:activity_completion` (float) and `:distribution_group` (`t:group/0`) to every student
  in `students`, without modifying any other field.

  Each student map must already carry `:proficiency` (number or `nil`),
  `:activities_attempted_count` (non-negative integer), and `:total_related_activities`
  (non-negative integer). A student with `total_related_activities == 0` is treated as 0%
  activity completion.
  """
  @spec assign([map()]) :: [map()]
  def assign(students) when is_list(students) do
    Enum.map(students, &assign_one/1)
  end

  defp assign_one(student) do
    activity_completion = activity_completion_for(student)
    group = group_for(Map.get(student, :proficiency), activity_completion)

    Map.merge(student, %{
      activity_completion: activity_completion,
      distribution_group: group
    })
  end

  defp activity_completion_for(%{total_related_activities: total})
       when total == 0 or is_nil(total),
       do: 0.0

  defp activity_completion_for(%{
         activities_attempted_count: attempted,
         total_related_activities: total
       }),
       do: attempted / total
end

defmodule Oli.Analytics.XAPI.StatementFactory do
  alias Oli.Analytics.Summary.AttemptGroup

  alias Oli.Analytics.XAPI.Events.Attempt.{
    PageAttemptEvaluated,
    PartAttemptEvaluated,
    ActivityAttemptEvaluated
  }

  def to_statements(%AttemptGroup{
        context: context,
        activity_attempts: activity_attempts,
        part_attempts: part_attempts,
        resource_attempt: resource_attempt
      }) do
    parts_and_activities =
      Enum.map(part_attempts, fn part_attempt ->
        PartAttemptEvaluated.new(context, part_attempt, resource_attempt)
      end) ++
        Enum.map(activity_attempts, fn activity_attempt ->
          ActivityAttemptEvaluated.new(context, activity_attempt, resource_attempt)
        end)

    case resource_attempt.lifecycle_state do
      :evaluated -> [PageAttemptEvaluated.new(context, resource_attempt) | parts_and_activities]
      _ -> parts_and_activities
    end
  end
end

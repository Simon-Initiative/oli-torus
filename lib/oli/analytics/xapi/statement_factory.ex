defmodule Oli.Analytics.XAPI.StatementFactory do
  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Delivery.Experiments.AttemptAttributions
  alias Oli.Experiments.XAPI.Attributions

  alias Oli.Analytics.XAPI.Events.Attempt.{
    PageAttemptEvaluated,
    PartAttemptEvaluated,
    ActivityAttemptEvaluated
  }

  def to_statements(
        %AttemptGroup{
          context: context,
          activity_attempts: activity_attempts,
          part_attempts: part_attempts,
          resource_attempt: resource_attempt
        } = attempt_group
      ) do
    attributions = AttemptAttributions.for_attempt_group(attempt_group)

    parts_and_activities =
      Enum.map(part_attempts, fn part_attempt ->
        PartAttemptEvaluated.new(context, part_attempt, resource_attempt)
        |> Attributions.attach_attributions(
          get_in(attributions, [:part_attempts, part_attempt.attempt_guid]) || []
        )
      end) ++
        Enum.map(activity_attempts, fn activity_attempt ->
          ActivityAttemptEvaluated.new(context, activity_attempt, resource_attempt)
          |> Attributions.attach_attributions(
            get_in(attributions, [:activity_attempts, activity_attempt.attempt_guid]) || []
          )
        end)

    case resource_attempt.lifecycle_state do
      :evaluated ->
        [
          PageAttemptEvaluated.new(context, resource_attempt)
          |> Attributions.attach_attributions(Map.get(attributions, :page_attempt, []))
          | parts_and_activities
        ]

      _ ->
        parts_and_activities
    end
  end
end

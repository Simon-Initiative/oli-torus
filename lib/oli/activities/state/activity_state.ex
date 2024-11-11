defmodule Oli.Activities.State.ActivityState do
  alias Oli.Activities.State.PartState
  alias Oli.Activities.Model
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Delivery.Evaluation.{Explanation, ExplanationContext}

  @enforce_keys [
    :activityId,
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :dateSubmitted,
    :lifecycle_state,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts,
    :groupId
  ]

  @derive Jason.Encoder
  defstruct [
    :activityId,
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :dateSubmitted,
    :lifecycle_state,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts,
    :groupId
  ]

  @spec from_attempt(
          %Oli.Delivery.Attempts.Core.ActivityAttempt{},
          [%Oli.Delivery.Attempts.Core.PartAttempt{}],
          %Oli.Activities.Model{},
          %Oli.Delivery.Attempts.Core.ResourceAttempt{} | nil,
          %Oli.Resources.Revision{} | nil,
          %Oli.Delivery.Settings.Combined{}
        ) ::
          %Oli.Activities.State.ActivityState{}
  def from_attempt(
        %ActivityAttempt{} = attempt,
        part_attempts,
        %Model{} = model,
        resource_attempt,
        page_revision,
        effective_settings
      ) do
    # Create the part states, and where we encounter parts from the model
    # that do not have an attempt we create the default state
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.part_id, p) end)

    explanation_provider_fn = fn part, part_attempt ->
      case resource_attempt do
        nil ->
          nil

        _ ->
          Explanation.get_explanation(%ExplanationContext{
            part: part,
            part_attempt: part_attempt,
            activity_attempt: attempt,
            resource_attempt: resource_attempt,
            resource_revision: page_revision,
            effective_settings: effective_settings
          })
      end
    end

    parts =
      Enum.map(model.parts, fn part ->
        Map.get(attempt_map, part.id) |> PartState.from_attempt(part, explanation_provider_fn)
      end)

    has_more_attempts =
      case effective_settings.max_attempts do
        0 -> true
        max -> attempt.attempt_number < max
      end

    %Oli.Activities.State.ActivityState{
      activityId: attempt.resource_id,
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      dateSubmitted: attempt.date_submitted,
      lifecycle_state: attempt.lifecycle_state,
      score: attempt.score,
      outOf: attempt.out_of,
      hasMoreAttempts: has_more_attempts,
      parts: parts,
      groupId: attempt.group_id
    }
  end

  def create_preview_state(transformed_model, group_id \\ nil) do
    %Oli.Activities.State.ActivityState{
      activityId: 1,
      attemptGuid: UUID.uuid4(),
      attemptNumber: 1,
      dateEvaluated: nil,
      dateSubmitted: nil,
      lifecycle_state: :active,
      score: nil,
      outOf: nil,
      hasMoreAttempts: true,
      groupId: group_id,
      parts:
        Enum.map(transformed_model["authoring"]["parts"], fn p ->
          %Oli.Activities.State.PartState{
            attemptGuid: p["id"],
            attemptNumber: 1,
            dateEvaluated: nil,
            dateSubmitted: nil,
            score: nil,
            outOf: nil,
            response: nil,
            feedback: nil,
            explanation: nil,
            hints: [],
            # Activities save empty hints to preserve the "deer in headlights" / "cognitive" / "bottom out"
            # hint ordering. Empty hints are filtered out here.
            hasMoreHints:
              p["hints"]
              |> Oli.Activities.ParseUtils.remove_empty()
              |> length > 0,
            hasMoreAttempts: true,
            partId: p["id"]
          }
        end)
    }
  end
end

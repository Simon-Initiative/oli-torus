defmodule Oli.Activities.State.PartState do
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Activities.Model.Part
  alias Oli.Activities.ParseUtils
  alias Oli.Delivery.Evaluation.{Explanation, ExplanationContext}

  @enforce_keys [
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :dateSubmitted,
    :score,
    :outOf,
    :response,
    :feedback,
    :hints,
    :hasMoreHints,
    :hasMoreAttempts,
    :partId
  ]

  @derive Jason.Encoder
  defstruct [
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :dateSubmitted,
    :score,
    :outOf,
    :response,
    :feedback,
    :hints,
    :hasMoreHints,
    :hasMoreAttempts,
    :partId
  ]

  def from_attempt(
        %PartAttempt{} = attempt,
        %Part{} = part
      ) do
    # TODO: consider refactoring this to be more efficient than a preload on every call
    %PartAttempt{
      activity_attempt:
        %ActivityAttempt{
          resource_attempt:
            %ResourceAttempt{
              revision: resource_revision
            } = resource_attempt
        } = activity_attempt
    } = Repo.preload(attempt, activity_attempt: [resource_attempt: [:revision]])

    # From the ids of hints displayed in the attempt, look up
    # the hint content from the part
    hint_map = Enum.reduce(part.hints, %{}, fn h, m -> Map.put(m, h.id, h) end)

    hints =
      Enum.map(attempt.hints, fn id -> Map.get(hint_map, id, nil) end)
      |> Enum.filter(fn id -> !is_nil(id) end)

    # Activities save empty hints to preserve the "deer in headlights" / "cognitive" / "bottom out"
    # hint ordering. Empty hints are filtered out here.
    real_part_hints =
      part.hints
      |> ParseUtils.remove_empty()

    feedback =
      attempt.feedback
      |> Explanation.maybe_set_feedback_explanation(%ExplanationContext{
        part: part,
        part_attempt: attempt,
        activity_attempt: activity_attempt,
        resource_attempt: resource_attempt,
        resource_revision: resource_revision
      })

    %Oli.Activities.State.PartState{
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      dateSubmitted: attempt.date_submitted,
      score: attempt.score,
      outOf: attempt.out_of,
      response: attempt.response,
      feedback: feedback,
      hints: hints,
      hasMoreHints: length(attempt.hints) < length(real_part_hints),
      hasMoreAttempts: true,
      partId: attempt.part_id
    }
  end
end

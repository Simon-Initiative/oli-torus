defmodule Oli.Activities.State.PartState do

  alias Oli.Delivery.Attempts.PartAttempt
  alias Oli.Activities.Model.Part

  @enforce_keys [
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
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
    :score,
    :outOf,
    :response,
    :feedback,
    :hints,
    :hasMoreHints,
    :hasMoreAttempts,
    :partId
  ]

  def from_attempt(%PartAttempt{} = attempt, %Part{} = part) do

    # From the ids of hints displayed in the attempt, look up
    # the hint content from the part
    hint_map = Enum.reduce(part.hints, %{}, fn h, m -> Map.put(m, h.id, h) end)
    hints = Enum.map(attempt.hints, fn id -> Map.get(hint_map, id, nil) end)
      |> Enum.filter(fn id -> !is_nil(id) end)

    %Oli.Activities.State.PartState{
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      score: attempt.score,
      outOf: attempt.out_of,
      response: attempt.response,
      feedback: attempt.feedback,
      hints: hints,
      hasMoreHints: length(attempt.hints) < length(part.hints),
      hasMoreAttempts: true,
      partId: attempt.part_id
    }

  end


end



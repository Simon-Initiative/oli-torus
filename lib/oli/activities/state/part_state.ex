defmodule Oli.Activities.State.PartState do

  alias Oli.Delivery.Attempts.PartAttempt
  alias Oli.Activities.Model.Part
  alias Oli.Activities.ParseUtils

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
    # This is the first location where we need to get the "real" hint count

    # From the ids of hints displayed in the attempt, look up
    # the hint content from the part
    hint_map = Enum.reduce(part.hints, %{}, fn h, m -> Map.put(m, h.id, h) end)
    hints = Enum.map(attempt.hints, fn id -> Map.get(hint_map, id, nil) end)
      |> Enum.filter(fn id -> !is_nil(id) end)

    # Activities save empty hints to preserve the "deer in headlights" / "cognitive" / "bottom out"
    # hint ordering. Empty hints are filtered out here.
    real_part_hints = part.hints
    |> ParseUtils.remove_empty
    IO.inspect(real_part_hints, label: "Real part hints")

    %Oli.Activities.State.PartState{
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      score: attempt.score,
      outOf: attempt.out_of,
      response: attempt.response,
      feedback: attempt.feedback,
      hints: real_part_hints,
      hasMoreHints: length(attempt.hints) < length(real_part_hints),
      hasMoreAttempts: true,
      partId: attempt.part_id
    }

  end
end

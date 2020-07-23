defmodule Oli.Activities.State.ActivityState do

  alias Oli.Activities.State.PartState
  alias Oli.Delivery.Attempts.ActivityAttempt
  alias Oli.Activities.Model

  @enforce_keys [
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts
  ]

  @derive Jason.Encoder
  defstruct [
    :attemptGuid,
    :attemptNumber,
    :dateEvaluated,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts
  ]

  @spec from_attempt(Oli.Delivery.Attempts.ActivityAttempt.t(), [Oli.Delivery.Attempts.PartAttempt.t()], Oli.Activities.Model.t()) ::
          %Oli.Activities.State.ActivityState{}
  def from_attempt(%ActivityAttempt{} = attempt, part_attempts, %Model{} = model) do

    # Create the part states, and where we encounter parts from the model
    # that do not have an attempt we create the default state
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.part_id, p) end)
    parts = Enum.map(model.parts, fn part -> Map.get(attempt_map, part.id) |> PartState.from_attempt(part) end)

    has_more_attempts = case attempt.revision.max_attempts do
      0 -> true
      max -> attempt.attempt_number < max
    end

    %Oli.Activities.State.ActivityState{
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      score: attempt.score,
      outOf: attempt.out_of,
      hasMoreAttempts: has_more_attempts,
      parts: parts
    }

  end

  def create_preview_state(transformed_model) do
    %Oli.Activities.State.ActivityState{
      attemptGuid: UUID.uuid4(),
      attemptNumber: 1,
      dateEvaluated: nil,
      score: nil,
      outOf: nil,
      hasMoreAttempts: true,
      parts: Enum.map(transformed_model["authoring"]["parts"], fn p ->
        %Oli.Activities.State.PartState{
          attemptGuid: p["id"],
          attemptNumber: 1,
          dateEvaluated: nil,
          score: nil,
          outOf: nil,
          response: nil,
          feedback: nil,
          hints: [],
          # Activities save empty hints to preserve the "deer in headlights" / "cognitive" / "bottom out"
          # hint ordering. Empty hints are filtered out here.
          hasMoreHints: (p["hints"]
            |> Oli.Activities.ParseUtils.remove_empty
            |> length) > 0,
          hasMoreAttempts: true,
          partId: p["id"],
        }
      end)
    }
  end
end

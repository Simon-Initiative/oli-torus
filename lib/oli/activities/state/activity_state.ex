defmodule Oli.Activities.State.ActivityState do

  alias Oli.Activities.State.PartState
  alias Oli.Delivery.Attempts.ResourceAttempt
  alias Oli.Activities.Model

  @enforce_keys [
    :attemptNumber,
    :dateEvaluated,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts
  ]

  @derive Jason.Encoder
  defstruct [
    :attemptNumber,
    :dateEvaluated,
    :score,
    :outOf,
    :hasMoreAttempts,
    :parts
  ]

  @spec from_attempt(Oli.Delivery.Attempts.ResourceAttempt.t(), [Oli.Delivery.Attempts.PartAttempt.t()], Oli.Activities.Model.t()) ::
          %Oli.Activities.State.ActivityState{}
  def from_attempt(%ResourceAttempt{} = attempt, part_attempts, %Model{} = model) do

    # Create the part states, and where we encounter parts from the model
    # that do not have an attempt we create the default state
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.part_id, p) end)

    parts = Enum.map(model.parts, fn part ->
      case Map.get(attempt_map, part.id) do
        nil -> PartState.default_state(part)
        attempt -> PartState.from_attempt(attempt, part)
      end

    end)


    %Oli.Activities.State.ActivityState{
      attemptNumber: attempt.attempt_number,
      dateEvaluated: attempt.date_evaluated,
      score: attempt.score,
      outOf: attempt.out_of,
      hasMoreAttempts: true,
      parts: parts
    }

  end

  def default_state(%Model{} = model) do

    %Oli.Activities.State.ActivityState{
      attemptNumber: 1,
      dateEvaluated: nil,
      score: nil,
      outOf: nil,
      hasMoreAttempts: true,
      parts: Enum.map(model.parts, &PartState.default_state(&1))
    }

  end

end



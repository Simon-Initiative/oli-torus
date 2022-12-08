defmodule Oli.Activities.State do
  alias Oli.Activities.State.ActivityState
  alias Oli.Activities.Model

  @doc """
  From a map of activity ids to {%ActivityAttempt, PartAttemptMap},
  produce the corresponding activity state representation,
  returning those in a map of activity ids to the state.
  """
  def from_attempts(latest_attempts, resource_attempt, page_revision) do
    Enum.map(latest_attempts, fn {id, {activity_attempt, part_attempts}} ->
      {:ok, model} = Oli.Delivery.Attempts.Core.select_model(activity_attempt) |> Model.parse()

      {id,
       ActivityState.from_attempt(
         activity_attempt,
         Map.values(part_attempts),
         model,
         resource_attempt,
         page_revision
       )}
    end)
    |> Map.new()
  end
end

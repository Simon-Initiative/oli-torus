defmodule Oli.Activities.State do

  alias Oli.Activities.State.ActivityState
  alias Oli.Activities.Model

  @doc """
  From a map of activity ids to {%ActivityAttempt, PartAttemptMap},
  produce the corresponding activity state representation,
  returning those in a map of activity ids to the state.
  """
  def from_attempts(latest_attempts) do
    Enum.map(latest_attempts, fn {id, {activity_attempt, part_attempts}} ->
      {:ok, model} = Map.get(activity_attempt, :transformed_model) |> Model.parse()

      {id, ActivityState.from_attempt(activity_attempt, Map.values(part_attempts), model)}
    end) |> Map.new
  end

end


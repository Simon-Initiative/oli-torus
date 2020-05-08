defmodule Oli.Activities.State do

  alias Oli.Activities.State.ActivityState
  alias Oli.Activities.Model

  @doc """
  From a map of activity ids to their resolved revisions,
  and a map of activity ids to their latest resource and part
  attempts, produce the corresponding activity state representation,
  returning those in a map of activity ids to the state.
  """
  def from_attempts(activity_ids, revision_map, latest_attempts) do

    Enum.reduce(activity_ids, %{}, fn id, m ->

      {:ok, model} = Map.get(revision_map, id) |> Map.get(:content) |> Model.parse()

      state = case Map.get(latest_attempts, id) do
        {attempt, part_attempts} -> ActivityState.from_attempt(attempt, Map.values(part_attempts), model)
        nil -> ActivityState.default_state(model)
      end

      Map.put(m, id, state)

    end)

  end

end


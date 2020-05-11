defmodule Oli.Delivery.Page.ActivityContext do
  @moduledoc """
  Defines the context required to render an activity in delivery mode.
  """

  alias Oli.Delivery.Page.ModelPruner
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Delivery.Attempts.ActivityAttempt
  alias Oli.Activities.State
  alias Oli.Activities.State.ActivityState
  alias Oli.Activities
  alias Phoenix.HTML

  @doc """
  Creates a mapping of activity id to an `%ActivitySummary` struct, based
  off of the supplied list of activity ids and a map of resource ids to
  resolved revisions.
  """
  @spec create_context_map(%{}) :: %{}
  def create_context_map(latest_attempts) do

    # get a view of all current registered activity types
    registrations = Activities.list_activity_registrations()
    reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

    activity_states = State.from_attempts(latest_attempts)

    Enum.map(latest_attempts, fn {id, {%ActivityAttempt{transformed_model: model, revision: revision}, _}} ->

      # the activity type this revision pertains to
      type = Map.get(reg_map, revision.activity_type_id)
      state = Map.get(activity_states, id)

      {id, %ActivitySummary{
        id: id,
        model: prepare_model(model),
        state: prepare_state(state),
        delivery_element: type.delivery_element,
        script: type.delivery_script
      }}
    end)
    |> Map.new

  end

  defp prepare_model(model) do
    case ModelPruner.prune(model) |> Jason.encode() do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  defp prepare_state(%ActivityState{} = state) do
    case Jason.encode(state) do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  defp encode(s) do
    {:safe, encoded} = HTML.html_escape(s)
    IO.iodata_to_binary(encoded)
  end

end

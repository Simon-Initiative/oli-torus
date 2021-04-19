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
  @spec create_context_map(boolean(), %{}) :: %{}
  def create_context_map(graded, latest_attempts) do
    # get a view of all current registered activity types
    registrations = Activities.list_activity_registrations()
    reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

    activity_states = State.from_attempts(latest_attempts)

    Enum.map(latest_attempts, fn {id,
                                  {%ActivityAttempt{transformed_model: model, revision: revision},
                                   _}} ->
      # the activity type this revision pertains to
      type = Map.get(reg_map, revision.activity_type_id)
      state = Map.get(activity_states, id)

      {id,
       %ActivitySummary{
         id: id,
         attempt_guid: state.attemptGuid,
         model: prepare_model(model),
         state: prepare_state(state),
         delivery_element: type.delivery_element,
         script: type.delivery_script,
         graded: graded
       }}
    end)
    |> Map.new()
  end

  @doc """
  Takes a full context map produced by create_context_map/2 and 'thins' it out to
  leave only the id, the delivery element name and the attempt guid. This is to allow
  a page implementation that wishes to avoid injecting a potentially large number of
  activities (and their full state and model) into a server rendered document.
  """
  def to_thin_context_map(context_map) do
    Enum.map(context_map, fn {k,
                              %{
                                id: id,
                                attempt_guid: attempt_guid,
                                delivery_element: delivery_element
                              }} ->
      {k,
       %{
         id: id,
         attemptGuid: attempt_guid,
         deliveryElement: delivery_element
       }}
    end)
    |> Map.new()
  end

  def prepare_model(model, opts \\ []) do
    model = if Keyword.get(opts, :prune, true), do: ModelPruner.prune(model), else: model

    case Jason.encode(model) do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  def prepare_state(%ActivityState{} = state) do
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

defmodule Oli.Delivery.Page.ActivityContext do
  @moduledoc """
  Defines the context required to render an activity in delivery mode.
  """

  alias Oli.Delivery.Page.ModelPruner
  alias Oli.Rendering.Activity.ActivitySummary
  alias Phoenix.HTML

  @doc """
  Creates a mapping of activity id to an `%ActivitySummary` struct, based
  off of the supplied list of activity ids and a map of resource ids to
  resolved revisions.
  """
  @spec create_context_map([number], %{}, [], %{}) :: %{}
  def create_context_map(activity_ids, revisions, registrations, active_attempt_states) do

    reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

    Enum.reduce(activity_ids, %{}, fn id, m ->

      # the activity type this revision pertains to
      type = Map.get(reg_map, Map.get(revisions, id) |> Map.get(:activity_type_id))

      Map.put(m, id, %ActivitySummary{
        id: id,
        slug: Map.get(revisions, id) |> Map.get(:slug),
        model: Map.get(revisions, id) |> prepare_model(),
        state: Map.get(active_attempt_states, id, %{}) |> prepare_state(),
        delivery_element: type.delivery_element,
        script: type.delivery_script
      })
    end)
  end

  defp prepare_model(%{content: content}) do
    case ModelPruner.prune(content) |> Jason.encode() do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  defp prepare_state(state) do
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

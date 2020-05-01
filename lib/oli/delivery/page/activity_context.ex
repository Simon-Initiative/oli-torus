defmodule Oli.Delivery.Page.ActivityContext do
  @moduledoc """
  Defines the context required to render an activity in delivery mode.
  """

  alias Oli.Delivery.Page.ModelPruner

  @enforce_keys [:slug, :element, :script, :model, :state, :title, :friendly_name]
  defstruct [
    :slug,          # slug of the resolved activity revision
    :element,       # web component element name to render for delivery
    :script,        # path to the script file that defines the web component
    :model,         # the pruned model of the activity, as a map
    :state,         # the state of the student's latest attempt
    :title,         # the title of this activity instance
    :friendly_name  # the friendly name of the type of this activity
  ]

  @doc """
  Creates a mapping of activity id to an `%ActivityContext` struct, based
  off of the supplied list of activity ids and a map of resource ids to
  resolved revisions.
  """
  @spec create_context_map([number], %{}, []) :: %{}
  def create_context_map(activity_ids, revisions, registrations) do

    reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

    Enum.reduce(activity_ids, %{}, fn id, m ->

      # the activity type this revision pertains to
      type = Map.get(reg_map, Map.get(revisions, id) |> Map.get(:activity_type_id))

      Map.put(m, id, %Oli.Delivery.Page.ActivityContext{
        slug: Map.get(revisions, id) |> Map.get(:slug),
        model: Map.get(revisions, id) |> Map.get(:content) |> ModelPruner.prune(),
        state: %{},
        title: Map.get(revisions, id) |> Map.get(:title),
        element: type.delivery_element,
        script: type.delivery_script,
        friendly_name: type.title
      })
    end)
  end



end

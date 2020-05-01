defmodule Oli.Rendering.Activity.ActivitySummary do
  @moduledoc """
  Defines the struct that contains necessary activity data used by the activity renderer.
  These ActivitySummary structs are given to the renderer via the rendering context as
  a map of activity ids to ActivitySummary called activity_map
  """

  @enforce_keys [
    :id,
    :model_json,
    :delivery_element
  ]
  defstruct [
    # id of the activity
    :id,
    # serialized delivery-safe json model for the activity
    :model_json,
    # activity element tag for the web component
    :delivery_element
  ]

end

defmodule Oli.Rendering.Activity.ActivitySummary do

  @enforce_keys [
    :slug,
    :model_json,
    :delivery_element
  ]
  defstruct [
    :slug,
    :model_json,
    :delivery_element
  ]

end

defmodule Oli.Rendering.Activity.ActivitySummary do

  @enforce_keys [
    :id,
    :model_json,
    :delivery_element
  ]
  defstruct [
    :id,
    :model_json,
    :delivery_element
  ]

end

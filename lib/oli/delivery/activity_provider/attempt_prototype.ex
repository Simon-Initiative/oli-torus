defmodule Oli.Delivery.ActivityProvider.AttemptPrototype do
  defstruct [
    :revision,
    :activity_id,
    :transformed_model,
    :scoreable,
    :survey_id,
    :group_id,
    :selection_id,
    :inherit_state_from_previous
  ]
end

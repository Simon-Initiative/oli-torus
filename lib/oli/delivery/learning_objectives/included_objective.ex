defmodule Oli.Delivery.LearningObjectives.IncludedObjective do
  @moduledoc """
  Render-ready objective metadata discovered for a Learning Objectives page element.
  """

  @enforce_keys [:resource_id, :title]
  defstruct resource_id: nil,
            title: nil,
            parent_resource_id: nil,
            children: [],
            related_activity_ids: [],
            directly_matched?: false

  @type t :: %__MODULE__{
          resource_id: integer(),
          title: String.t(),
          parent_resource_id: integer() | nil,
          children: [integer()],
          related_activity_ids: [integer()],
          directly_matched?: boolean()
        }
end

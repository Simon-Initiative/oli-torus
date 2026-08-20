defmodule Oli.Experiments.RecordExposureRequest do
  @moduledoc """
  Delivery request for recording a learner exposure to an assigned condition.

  `page_resource_id` and `content_element_id` are required server-resolved placement
  identifiers. The experiment context validates them before emitting evidence.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :key,
    :scope,
    :assignment_id,
    :page_resource_id,
    :content_element_id,
    :content_revision_id,
    :exposed_at
  ]

  @type t :: %__MODULE__{
          key: String.t(),
          scope: Scope.t(),
          assignment_id: integer(),
          page_resource_id: integer(),
          content_element_id: String.t(),
          content_revision_id: integer(),
          exposed_at: DateTime.t() | nil
        }
end

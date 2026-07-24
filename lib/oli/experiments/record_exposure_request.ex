defmodule Oli.Experiments.RecordExposureRequest do
  @moduledoc """
  Delivery request for recording a learner exposure to an assigned condition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :key,
    :scope,
    :assignment_id,
    :content_revision_id,
    :exposed_at
  ]

  @type t :: %__MODULE__{
          key: String.t(),
          scope: Scope.t(),
          assignment_id: integer(),
          content_revision_id: integer(),
          exposed_at: DateTime.t() | nil
        }
end

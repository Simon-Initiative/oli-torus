defmodule Oli.Experiments.RecordExposureRequest do
  @moduledoc """
  Delivery request for recording a learner exposure to an assigned condition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :assignment_id,
    :content_revision_id,
    :idempotency_key,
    :exposed_at
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          assignment_id: integer(),
          content_revision_id: integer(),
          idempotency_key: String.t(),
          exposed_at: DateTime.t() | nil
        }
end

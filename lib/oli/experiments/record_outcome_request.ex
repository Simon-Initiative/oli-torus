defmodule Oli.Experiments.RecordOutcomeRequest do
  @moduledoc """
  Request for associating an outcome with an experiment assignment.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :assignment_id,
    :activity_attempt_id,
    :resource_attempt_id,
    :activity_resource_id,
    :score,
    :out_of,
    :metadata,
    :observed_at,
    :idempotency_key
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          assignment_id: integer(),
          activity_attempt_id: integer() | nil,
          resource_attempt_id: integer() | nil,
          activity_resource_id: integer() | nil,
          score: float() | nil,
          out_of: float() | nil,
          metadata: map() | nil,
          observed_at: DateTime.t() | nil,
          idempotency_key: String.t()
        }
end

defmodule Oli.Experiments.RecordRewardRequest do
  @moduledoc """
  Request for recording a reward event for an experiment assignment.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :assignment_id,
    :outcome_id,
    :outcome_idempotency_key,
    :reward_value,
    :reward_source,
    :metadata,
    :idempotency_key
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          assignment_id: integer(),
          outcome_id: integer() | nil,
          outcome_idempotency_key: String.t() | nil,
          reward_value: float(),
          reward_source: String.t(),
          metadata: map() | nil,
          idempotency_key: String.t()
        }
end

defmodule Oli.Experiments.RecordRewardRequest do
  @moduledoc """
  Request for recording a reward event for an experiment assignment.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :key,
    :scope,
    :assignment_id,
    :outcome_key,
    :reward_value,
    :reward_source,
    :metadata
  ]

  @type t :: %__MODULE__{
          key: String.t(),
          scope: Scope.t(),
          assignment_id: integer(),
          outcome_key: String.t() | nil,
          reward_value: float(),
          reward_source: String.t(),
          metadata: map() | nil
        }
end

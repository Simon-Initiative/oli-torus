defmodule Oli.Experiments.RewardReceipt do
  @moduledoc """
  Public receipt for idempotent reward recording.
  """

  defstruct [
    :id,
    :assignment_id,
    :outcome_id,
    :outcome_idempotency_key,
    :idempotency_key,
    :recorded_at,
    reused?: false
  ]

  @type t :: %__MODULE__{}
end

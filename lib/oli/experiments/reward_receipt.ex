defmodule Oli.Experiments.RewardReceipt do
  @moduledoc """
  Public receipt for idempotent reward recording.
  """

  defstruct [
    :key,
    :assignment_id,
    :outcome_key,
    :recorded_at,
    reused?: false
  ]

  @type t :: %__MODULE__{}
end

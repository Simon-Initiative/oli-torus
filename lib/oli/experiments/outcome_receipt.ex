defmodule Oli.Experiments.OutcomeReceipt do
  @moduledoc """
  Public receipt for idempotent outcome recording.
  """

  defstruct [:key, :assignment_id, :recorded_at, reused?: false]

  @type t :: %__MODULE__{}
end

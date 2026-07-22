defmodule Oli.Experiments.OutcomeReceipt do
  @moduledoc """
  Public receipt for idempotent outcome recording.
  """

  defstruct [:id, :assignment_id, :idempotency_key, :recorded_at, reused?: false]

  @type t :: %__MODULE__{}
end

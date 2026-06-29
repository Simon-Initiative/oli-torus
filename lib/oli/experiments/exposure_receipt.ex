defmodule Oli.Experiments.ExposureReceipt do
  @moduledoc """
  Public receipt for idempotent exposure recording.
  """

  defstruct [:id, :assignment_id, :idempotency_key, :recorded_at, reused?: false]

  @type t :: %__MODULE__{}
end

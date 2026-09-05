defmodule Oli.Experiments.ExposureReceipt do
  @moduledoc """
  Public receipt for idempotent exposure recording.
  """

  defstruct [:key, :assignment_id, :recorded_at, reused?: false]

  @type t :: %__MODULE__{}
end

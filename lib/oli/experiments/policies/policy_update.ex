defmodule Oli.Experiments.Policies.PolicyUpdate do
  @moduledoc """
  Policy reward update outcome.
  """

  defstruct [:algorithm_version, :previous_state, :next_state, :update_reason, counters: %{}]

  @type t :: %__MODULE__{}
end

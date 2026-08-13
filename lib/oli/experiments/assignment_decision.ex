defmodule Oli.Experiments.AssignmentDecision do
  @moduledoc """
  Public result for delivery assignment decisions.
  """

  defstruct [
    :status,
    :experiment_id,
    :condition_id,
    :condition_code,
    :option_id,
    :assignment_id,
    :reused?
  ]

  @type t :: %__MODULE__{}
end

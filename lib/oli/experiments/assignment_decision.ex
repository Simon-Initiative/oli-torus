defmodule Oli.Experiments.AssignmentDecision do
  @moduledoc """
  Public result for delivery assignment decisions.
  """

  defstruct [
    :status,
    :experiment_id,
    :decision_point_id,
    :condition_id,
    :condition_code,
    :assignment_id,
    :reused?
  ]

  @type t :: %__MODULE__{}
end

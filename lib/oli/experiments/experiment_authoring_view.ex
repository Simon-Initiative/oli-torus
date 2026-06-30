defmodule Oli.Experiments.ExperimentAuthoringView do
  @moduledoc """
  Public authoring view for an experiment definition graph.
  """

  defstruct [
    :definition,
    decision_points: [],
    conditions: [],
    assignment_counts: %{}
  ]

  @type t :: %__MODULE__{}
end

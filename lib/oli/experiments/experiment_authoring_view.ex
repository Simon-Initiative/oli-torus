defmodule Oli.Experiments.ExperimentAuthoringView do
  @moduledoc """
  Public authoring view for an experiment definition graph.
  """

  defstruct [
    :definition,
    conditions: [],
    interventions: [],
    assessment_bindings: [],
    assignment_counts: %{}
  ]

  @type t :: %__MODULE__{}
end

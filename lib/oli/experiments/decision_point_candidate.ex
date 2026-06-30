defmodule Oli.Experiments.DecisionPointCandidate do
  @moduledoc """
  Public alternatives decision point available for A/B testing authoring.
  """

  defstruct [
    :alternatives_resource_id,
    :alternatives_revision_id,
    :decision_point_key,
    :title,
    options: []
  ]

  @type t :: %__MODULE__{}
end

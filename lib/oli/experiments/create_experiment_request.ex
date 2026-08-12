defmodule Oli.Experiments.CreateExperimentRequest do
  @moduledoc """
  Request to create a native experiment definition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :slug,
    :name,
    :description,
    :algorithm,
    :section_ids,
    decision_points: [],
    conditions: [],
    assignment_unit: :enrollment
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          slug: String.t(),
          name: String.t(),
          description: String.t() | nil,
          algorithm: :weighted_random | :thompson_sampling,
          section_ids: [integer()] | nil,
          decision_points: [map()],
          conditions: [map()],
          assignment_unit: :enrollment
        }
end

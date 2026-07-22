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
    :decision_point,
    conditions: [],
    assignment_unit: :enrollment,
    policy_config: %{}
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          slug: String.t(),
          name: String.t(),
          description: String.t() | nil,
          algorithm: :weighted_random | :thompson_sampling,
          decision_point: map() | nil,
          conditions: [map()],
          assignment_unit: :enrollment,
          policy_config: map()
        }
end

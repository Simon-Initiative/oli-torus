defmodule Oli.Experiments.UpdateExperimentRequest do
  @moduledoc """
  Request to update mutable fields on a draft experiment definition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :slug,
    :name,
    :description,
    :algorithm,
    :assignment_unit,
    :policy_config,
    :decision_point,
    :conditions
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          slug: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          algorithm: :weighted_random | :thompson_sampling | nil,
          assignment_unit: :enrollment | nil,
          policy_config: map() | nil,
          decision_point: map() | nil,
          conditions: [map()] | nil
        }
end

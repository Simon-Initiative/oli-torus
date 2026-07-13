defmodule Oli.Experiments.ExperimentDefinition do
  @moduledoc """
  Public experiment definition returned from the experiments context.
  """

  defstruct [
    :id,
    :uuid,
    :institution_id,
    :project_id,
    :section_id,
    :slug,
    :name,
    :description,
    :state,
    :assignment_unit,
    :algorithm,
    :policy_config,
    :started_at,
    :ended_at
  ]

  @type t :: %__MODULE__{}
end

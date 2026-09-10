defmodule Oli.Experiments.ExperimentSectionParticipation do
  @moduledoc """
  Public authoring view of an experiment's current and stale section participation.
  """

  alias Oli.Experiments.EligibleExperimentSection

  @enforce_keys [:experiment_id, :eligible_sections, :selected_ids, :stale_sections]
  defstruct [:experiment_id, :eligible_sections, :selected_ids, :stale_sections]

  @type t :: %__MODULE__{
          experiment_id: integer(),
          eligible_sections: [EligibleExperimentSection.t()],
          selected_ids: [integer()],
          stale_sections: [EligibleExperimentSection.t()]
        }
end

defmodule Oli.Analytics.Datasets.BrowseJobOptions do

  defstruct [
    :project_id,
    :statuses,
    :job_type,
    :initiated_by_id
  ]

  @type t() :: %__MODULE__{
          project_id: integer(),
          statuses: list(),
          job_type: atom(),
          initiated_by_id: integer()
        }
end

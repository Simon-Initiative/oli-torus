defmodule Oli.Activities.Realizer.Query.Source do
  @enforce_keys [:publication_id, :blacklisted_activity_ids]
  defstruct [:publication_id, :blacklisted_activity_ids]

  @type t() :: %__MODULE__{
          publication_id: integer(),
          blacklisted_activity_ids: [integer()]
        }
end

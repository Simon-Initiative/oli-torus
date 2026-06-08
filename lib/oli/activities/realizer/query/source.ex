defmodule Oli.Activities.Realizer.Query.Source do
  @moduledoc """
  The source of an activity query.

  The publication id is, obviously, the id of the project publication
  to draw activities from.

  `blacklisted_activity_ids` is a list of activity ids to explicitly
  exclude from selection. This exists to power features like "do not include
  activities in this selection that student's have encountered in previous
  attempts".

  `activity_resource_ids` optionally limits the query to specific activity
  resources. A `nil` value preserves the default behavior of querying all
  matching activities.

  `page_exclusions` optionally carries instructor customization state for the
  current section page during delivery realization.
  """

  @enforce_keys [:publication_id, :blacklisted_activity_ids, :section_slug]
  defstruct [
    :publication_id,
    :blacklisted_activity_ids,
    :section_slug,
    :bank,
    :activity_resource_ids,
    :page_exclusions
  ]

  @type t() :: %__MODULE__{
          publication_id: integer(),
          blacklisted_activity_ids: [integer()],
          section_slug: String.t(),
          bank: list(),
          activity_resource_ids: [integer()] | nil,
          page_exclusions: Oli.Delivery.InstructorCustomizations.PageExclusions.t() | nil
        }
end

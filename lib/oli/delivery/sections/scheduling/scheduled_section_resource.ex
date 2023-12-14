defmodule Oli.Delivery.Sections.Scheduling.ScheduledSectionResource do
  @moduledoc """
  Represents a scheduled resource for a course section.
  """

  alias Oli.Delivery.Sections.SectionResource

  defstruct [
    :section_resource,
    :parent_resource_id,
    :month,
    :week
  ]

  @enforce_keys [
    :section_resource,
    :parent_resource_id,
    :month,
    :week
  ]

  @type t() :: %__MODULE__{
          section_resource: SectionResource.t(),
          parent_resource_id: integer(),
          month: integer(),
          week: integer()
        }
end

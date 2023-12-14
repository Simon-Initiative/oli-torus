defmodule Oli.Delivery.Sections.Scheduling.ScheduledRange do
  @moduledoc """
  Represents a scheduled range for a course section.
  """

  defstruct [
    :start_date,
    :end_date
  ]

  @enforce_keys [
    :start_date,
    :end_date
  ]

  @type t() :: %__MODULE__{
          start_date: Date.t(),
          end_date: Date.t()
        }
end

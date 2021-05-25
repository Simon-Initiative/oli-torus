defmodule Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary do
  @moduledoc """
  A context for finalizing a page.

  section_slug - Slug identifier for the course section
  resource_attempt - The resource attempt to finalize
  """

  @enforce_keys [
    :resource_access,
    :part_attempt_guids
  ]

  defstruct [
    :resource_access,
    :part_attempt_guids
  ]

  @type t() :: %__MODULE__{
          resource_access: any(),
          part_attempt_guids: list()
        }
end

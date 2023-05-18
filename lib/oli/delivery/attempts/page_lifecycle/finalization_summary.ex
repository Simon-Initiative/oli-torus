defmodule Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary do
  @moduledoc """
  A summary of the result of page finalization.

  resource_access - Slug identifier for the course section
  part_attempt_guids - The resource attempt to finalize
  lifecycle_state - The new lifecycle state for the page, after finalization. Can
                    only be either `:evaluated` or `:submitted`
  """

  @enforce_keys [
    :resource_access,
    :part_attempt_guids,
    :lifecycle_state,
    :graded,
    :effective_settings
  ]

  defstruct [
    :resource_access,
    :part_attempt_guids,
    :lifecycle_state,
    :graded,
    :effective_settings
  ]

  @type t() :: %__MODULE__{
          resource_access: any(),
          part_attempt_guids: list(),
          lifecycle_state: atom(),
          graded: boolean(),
          effective_settings: struct()
        }
end

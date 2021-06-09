defmodule Oli.Delivery.Attempts.PageLifecycle.FinalizationContext do
  @moduledoc """
  A context for finalizing a page.

  section_slug - Slug identifier for the course section
  resource_attempt - The resource attempt to finalize
  """

  @enforce_keys [
    :section_slug,
    :resource_attempt
  ]

  defstruct [
    :section_slug,
    :resource_attempt
  ]

  @type t() :: %__MODULE__{
          section_slug: String.t(),
          resource_attempt: any()
        }
end

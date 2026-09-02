defmodule Oli.Delivery.Attempts.PageLifecycle.FinalizationContext do
  @moduledoc """
  A context for finalizing a page.

  section_slug - Slug identifier for the course section
  resource_attempt - The resource attempt to finalize
  """

  @enforce_keys [
    :section_slug,
    :resource_attempt,
    :datashop_session_id,
    :effective_settings
  ]

  defstruct [
    :section_slug,
    :resource_attempt,
    :datashop_session_id,
    :effective_settings
  ]

  @type t() :: %__MODULE__{
          section_slug: String.t(),
          resource_attempt: any(),
          datashop_session_id: String.t(),
          effective_settings: Oli.Delivery.Settings.Combined.t()
        }
end

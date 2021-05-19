defmodule Oli.Delivery.Attempts.PageLifecycle.HistorySummary do
  @moduledoc """
  A summary of the history of attempts for a page.
  resource_access - The resource access record
  resource_attempts - Collection of resource attempt records
  """

  @enforce_keys [
    :resource_access,
    :resource_attempts
  ]

  defstruct [
    :resource_access,
    :resource_attempts
  ]

  @type t() :: %__MODULE__{
          resource_access: any(),
          resource_attempts: any()
        }
end

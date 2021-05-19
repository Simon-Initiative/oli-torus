defmodule Oli.Delivery.Attempts.PageLifecycle.AttemptState do
  @moduledoc """
  The complete state of a page attempt.
  resource_attempt - The resource attempt
  attempt_hierarchy - The activity attempt and part attempt hierarchy
  """

  @enforce_keys [
    :resource_attempt,
    :attempt_hierarchy
  ]

  defstruct [
    :resource_attempt,
    :attempt_hierarchy
  ]

  @type t() :: %__MODULE__{
          resource_attempt: any(),
          attempt_hierarchy: any()
        }
end

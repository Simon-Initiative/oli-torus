defmodule Oli.Delivery.Attempts.PageLifecycle.ReviewContext do
  @moduledoc """
  A context for reviewing a historical attempt.

  resource_attempt - The resource attempt to review
  """

  @enforce_keys [
    :resource_attempt
  ]

  defstruct [
    :resource_attempt
  ]

  @type t() :: %__MODULE__{
          resource_attempt: any()
        }
end

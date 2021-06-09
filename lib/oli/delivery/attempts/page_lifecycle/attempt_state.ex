defmodule Oli.Delivery.Attempts.PageLifecycle.AttemptState do
  @moduledoc """
  The complete state of a page attempt

  resource_attempt - The resource attempt record itself

  attempt_hierarchy - The activity attempt and part attempt hierarchy in the form of
  a map of activity resource id to tuples {%ActivityAttempt, part_attempt_map}, where part attempt
  map is a map of part ids to part attempt records.

  A full example of the attempt_hierarchy for two activities each with two parts would
  look like:

  ```
  %{
    45 => {%ActivityAttempt{}, %{"1" => %PartAttempt{}, "2" => PartAttempt{}}},
    67 => {%ActivityAttempt{}, %{"1" => %PartAttempt{}, "2" => PartAttempt{}}}
  }
  ```
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

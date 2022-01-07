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

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy

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

  def fetch_attempt_state(%ResourceAttempt{} = resource_attempt, %Revision{
        content: %{"advancedDelivery" => true}
      }) do
    {:ok,
     %__MODULE__{
       resource_attempt: resource_attempt,
       attempt_hierarchy: Hierarchy.thin_hierarchy(resource_attempt)
     }}
  end

  def fetch_attempt_state(%ResourceAttempt{} = resource_attempt, _) do
    {:ok,
     %__MODULE__{
       resource_attempt: resource_attempt,
       attempt_hierarchy: Hierarchy.full_hierarchy(resource_attempt)
     }}
  end
end

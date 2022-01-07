defmodule Oli.Delivery.Attempts.PageLifecycle.AttemptState do
  @moduledoc """
  The complete state of a page attempt

  resource_attempt - The resource attempt record itself

  attempt_hierarchy - The state of the activity attempts required for rendering

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

  @doc """
  The required attempt state for page rendering differs between basic and adaptive pages.
  A basic page needs the "full attempt hierarchy", that is, the resource attempt, and then a
  map of activity ids on that page to tuples of activity attempt and a part attempt mapping. For
  example:

  ```
  %{
    232 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}},
    233 => {%ActivityAttempt{}, %{ "1" => %PartAttempt{}, "2" => %PartAttempt{}}}
  }
  ```

  The adaptive page requires less information, which is also arranged in a different format. It
  uses simply a mapping of activity resource ids to a small set of data including the
  attempt guid and the name of the delivery element to use rendering. That looks like:any()

  ```
  %{
    232 => %{
      id: 232,
      attemptGuid: 2398298233,
      deliveryElement: "oli-adaptive-delivery"

    },
    233 => %{
      id: 233,
      attemptGuid: 223923892389,
      deliveryElement: "oli-adaptive-delivery"
    }
  }
  ```
  """
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

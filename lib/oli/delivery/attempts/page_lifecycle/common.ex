defmodule Oli.Delivery.Attempts.PageLifecycle.Common do
  alias Oli.Delivery.Attempts.PageLifecycle.{
    ReviewContext,
    Hierarchy,
    AttemptState
  }

  @doc """
  Common implementation for reviewing an attempt.
  """
  def review(%ReviewContext{
        resource_attempt: resource_attempt
      }) do
    status =
      case resource_attempt.date_evaluated do
        nil -> :in_progress
        _ -> :finalized
      end

    {:ok,
     {status,
      %AttemptState{
        resource_attempt: resource_attempt,
        attempt_hierarchy: Hierarchy.get_latest_attempts(resource_attempt.id)
      }}}
  end
end

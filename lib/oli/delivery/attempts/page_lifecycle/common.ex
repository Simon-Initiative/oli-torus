defmodule Oli.Delivery.Attempts.PageLifecycle.Common do
  alias Oli.Delivery.Attempts.PageLifecycle.{
    ReviewContext,
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

    {:ok, state} = AttemptState.fetch_attempt_state(resource_attempt, resource_attempt.revision)

    {:ok, {status, state}}
  end
end

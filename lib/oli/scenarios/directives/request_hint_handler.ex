defmodule Oli.Scenarios.Directives.RequestHintHandler do
  @moduledoc """
  Handles request_hint directives through the learner activity lifecycle.
  """

  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Scenarios.Directives.ActivityAttemptSupport
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, RequestHintDirective}

  @doc """
  Requests the next hint for the directive's active activity part attempt.
  """
  def handle(%RequestHintDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, attempt_state} <-
           ActivityAttemptSupport.get_attempt_state(
             state,
             directive.student,
             directive.section,
             directive.page
           ),
         {:ok, activity_revision} <-
           ActivityAttemptSupport.get_activity_revision(state, directive.activity_virtual_id),
         {:ok, activity_attempt_info} <-
           ActivityAttemptSupport.find_activity_attempt(attempt_state, activity_revision),
         {:ok, part_attempt} <-
           ActivityAttemptSupport.find_part_attempt(activity_attempt_info, directive.part_id),
         {:ok, _hint_result} <-
           ActivityLifecycle.request_hint(
             activity_attempt_info.attempt_guid,
             part_attempt.attempt_guid
           ) do
      {:ok, state}
    else
      {:error, reason} -> {:error, "Failed to request hint: #{format_reason(reason)}"}
    end
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end

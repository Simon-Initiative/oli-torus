defmodule Oli.Scenarios.Directives.ResetActivityHandler do
  @moduledoc """
  Handles reset_activity directives through the learner activity lifecycle.
  """

  alias Oli.Scenarios.Directives.{
    ActivityAttemptSupport,
    AttemptSupport
  }

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ResetActivityDirective}
  alias Oli.Scenarios.LearnerActions

  @doc """
  Resets the directive's activity and refreshes its page attempt state.
  """
  def handle(%ResetActivityDirective{} = directive, %ExecutionState{} = state) do
    datashop_session_id = Oli.Scenarios.LearnerSession.transient_id()

    with {:ok, user} <- AttemptSupport.get_user(state, directive.student),
         {:ok, section} <- AttemptSupport.get_section(state, directive.section),
         {:ok, page_revision} <-
           AttemptSupport.get_page_revision(state, directive.section, directive.page),
         {:ok, attempt_state} <-
           ActivityAttemptSupport.get_attempt_state(
             state,
             directive.student,
             directive.section,
             directive.page
           ),
         {:ok, activity_revision} <-
           ActivityAttemptSupport.get_activity_revision(
             state,
             directive.section,
             directive.activity_virtual_id
           ),
         {:ok, activity_attempt_info} <-
           ActivityAttemptSupport.find_activity_attempt(attempt_state, activity_revision),
         {:ok, _reset_result} <-
           LearnerActions.reset_activity(
             section,
             activity_attempt_info.activity_attempt,
             datashop_session_id
           ),
         {:ok, refreshed_attempt} <-
           AttemptSupport.visit_page(user, section, page_revision,
             datashop_session_id: datashop_session_id
           ) do
      {:ok,
       AttemptSupport.put_attempt_result(
         state,
         directive.student,
         directive.section,
         directive.page,
         refreshed_attempt
       )}
    else
      {:error, reason} -> {:error, "Failed to reset activity: #{format_reason(reason)}"}
    end
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end

defmodule Oli.Scenarios.Directives.FinalizeAttemptHandler do
  @moduledoc """
  Handles finalize_attempt directives by finalizing the learner's active page attempt
  through the real page lifecycle.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, FinalizeAttemptDirective}
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.LearnerActions

  def handle(%FinalizeAttemptDirective{} = directive, %ExecutionState{} = state) do
    key = {directive.student, directive.section, directive.page}

    datashop_session_id = Oli.Scenarios.LearnerSession.transient_id()

    with {:ok, section} <- fetch_section(state, directive.section),
         {:ok, resource_attempt} <- fetch_resource_attempt(state, key),
         {:ok, finalization_summary} <-
           LearnerActions.finalize(section, resource_attempt, datashop_session_id) do
      {:ok,
       %{
         state
         | page_attempts: Map.delete(state.page_attempts, key),
           finalized_attempts: Map.put(state.finalized_attempts, key, finalization_summary)
       }}
    else
      {:error, reason} ->
        {:error, "Failed to finalize attempt: #{format_reason(reason)}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp fetch_resource_attempt(state, key) do
    case Map.get(state.page_attempts, key) do
      nil ->
        {:error, "No active attempt found - student must visit page first"}

      {:not_started, _} ->
        {:error, "Page not started - cannot finalize attempt"}

      {_status, %{resource_attempt: %{} = resource_attempt}} ->
        {:ok, resource_attempt}

      {_status, _unexpected} ->
        {:error, "Stored page attempt does not contain a finalizable resource attempt"}
    end
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end

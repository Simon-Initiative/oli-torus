defmodule Oli.Scenarios.Directives.FinalizeAttemptHandler do
  @moduledoc """
  Handles finalize_attempt directives by finalizing the learner's active page attempt
  through the real page lifecycle.
  """

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, FinalizeAttemptDirective}
  alias Oli.Scenarios.Engine

  def handle(%FinalizeAttemptDirective{} = directive, %ExecutionState{} = state) do
    key = {directive.student, directive.section, directive.page}

    with {:ok, section} <- fetch_section(state, directive.section),
         {:ok, attempt_guid} <- fetch_attempt_guid(state, key),
         {:ok, finalization_summary} <-
           finalize_attempt(section.slug, attempt_guid) do
      {:ok,
       %{
         state
         | page_attempts: Map.delete(state.page_attempts, key),
           finalized_attempts: Map.put(state.finalized_attempts, key, finalization_summary)
       }}
    else
      {:error, reason} ->
        {:error, "Failed to finalize attempt: #{reason}"}
    end
  end

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp fetch_attempt_guid(state, key) do
    case Map.get(state.page_attempts, key) do
      nil ->
        {:error, "No active attempt found - student must visit page first"}

      {:not_started, _} ->
        {:error, "Page not started - cannot finalize attempt"}

      {_status, %{resource_attempt: %{attempt_guid: attempt_guid}}} ->
        {:ok, attempt_guid}

      {_status, _unexpected} ->
        {:error, "Stored page attempt does not contain a finalizable resource attempt"}
    end
  end

  defp finalize_attempt(section_slug, attempt_guid) do
    datashop_session_id = "session_#{System.unique_integer([:positive])}"

    case PageLifecycle.finalize(section_slug, attempt_guid, datashop_session_id) do
      {:ok, finalization_summary} ->
        {:ok, finalization_summary}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end

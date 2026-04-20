defmodule Oli.Scenarios.Directives.StartAttemptHandler do
  @moduledoc """
  Handles explicit graded attempt starts, including expected policy denials.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, StartAttemptDirective}
  alias Oli.Scenarios.Directives.AttemptSupport

  def handle(%StartAttemptDirective{} = directive, %ExecutionState{} = state) do
    expected = directive.expect || :started

    with {:ok, user} <- AttemptSupport.get_user(state, directive.student),
         {:ok, section} <- AttemptSupport.get_section(state, directive.section),
         {:ok, _enrollment} <- AttemptSupport.ensure_enrollment(user, section),
         {:ok, page_revision} <-
           AttemptSupport.get_page_revision(state, directive.section, directive.page) do
      start_result =
        user
        |> AttemptSupport.visit_page(section, page_revision, password: directive.password)
        |> AttemptSupport.normalize_start_error()

      handle_result(start_result, expected, directive, state)
    else
      {:error, reason} ->
        {:error, "Failed to start attempt: #{format_reason(reason)}"}
    end
  end

  defp handle_result({:ok, attempt_result}, :started, directive, state) do
    {:ok,
     AttemptSupport.put_attempt_result(
       state,
       directive.student,
       directive.section,
       directive.page,
       attempt_result
     )}
  end

  defp handle_result({:ok, _attempt_result}, expected, _directive, _state) do
    {:error, "Expected start_attempt to result in #{expected}, but attempt started"}
  end

  defp handle_result({:error, actual}, expected, _directive, state) when actual == expected,
    do: {:ok, state}

  defp handle_result({:error, actual}, expected, _directive, _state) do
    {:error, "Expected start_attempt to result in #{expected}, but got #{format_reason(actual)}"}
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)
end

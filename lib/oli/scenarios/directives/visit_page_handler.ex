defmodule Oli.Scenarios.Directives.VisitPageHandler do
  @moduledoc """
  Handles visit_page directives for simulating students visiting pages.

  This handler delegates to delivery page-visit orchestration and stores the
  resulting attempt state in the execution state.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, VisitPageDirective}
  alias Oli.Scenarios.Directives.AttemptSupport

  def handle(%VisitPageDirective{} = directive, %ExecutionState{} = state) do
    handle_visit(directive.student, directive.section, directive.page, state)
  end

  def handle_visit(student_name, section_name, page_title, %ExecutionState{} = state) do
    with {:ok, user} <- AttemptSupport.get_user(state, student_name),
         {:ok, section} <- AttemptSupport.get_section(state, section_name),
         {:ok, _enrollment} <- AttemptSupport.ensure_enrollment(user, section),
         {:ok, page_revision} <- AttemptSupport.get_page_revision(state, section_name, page_title),
         {:ok, attempt_result} <- AttemptSupport.visit_page(user, section, page_revision) do
      {:ok,
       AttemptSupport.put_attempt_result(
         state,
         student_name,
         section_name,
         page_title,
         attempt_result
       )}
    else
      {:error, reason} ->
        {:error, "Failed to visit page: #{format_reason(reason)}"}
    end
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)
end

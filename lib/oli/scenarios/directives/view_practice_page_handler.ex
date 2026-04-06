defmodule Oli.Scenarios.Directives.ViewPracticePageHandler do
  @moduledoc """
  Backward-compatible wrapper for the legacy view_practice_page directive.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ViewPracticePageDirective}
  alias Oli.Scenarios.Directives.VisitPageHandler

  def handle(%ViewPracticePageDirective{} = directive, %ExecutionState{} = state) do
    VisitPageHandler.handle_visit(directive.student, directive.section, directive.page, state)
  end
end

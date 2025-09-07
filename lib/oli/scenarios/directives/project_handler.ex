defmodule Oli.Scenarios.Directives.ProjectHandler do
  @moduledoc """
  Handles project creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.ProjectDirective
  alias Oli.Scenarios.{Builder, Engine}
  alias Oli.Scenarios.Types.ProjectSpec

  def handle(%ProjectDirective{name: name, title: title, root: root, objectives: objectives, tags: tags}, state) do
    try do
      # Build the project using existing Builder
      project_spec = %ProjectSpec{
        title: title || name,
        root: root,
        objectives: objectives,
        tags: tags
      }

      built_project =
        Builder.build!(
          project_spec,
          state.current_author,
          state.current_institution
        )

      # Store the built project in state
      new_state = Engine.put_project(state, name, built_project)

      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create project '#{name}': #{Exception.message(e)}"}
    end
  end
end

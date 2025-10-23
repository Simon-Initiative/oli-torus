defmodule Oli.Scenarios.Directives.PublishHandler do
  @moduledoc """
  Handles publish directives to publish outstanding changes to projects.
  """

  alias Oli.Scenarios.DirectiveTypes.PublishDirective
  alias Oli.Scenarios.Engine
  alias Oli.Publishing

  def handle(%PublishDirective{to: to_name, description: description}, state) do
    try do
      # Get the target project
      built_project =
        Engine.get_project(state, to_name) ||
          raise "Project '#{to_name}' not found"

      # Publish the outstanding changes
      pub_description = description || "Publishing changes"

      {:ok, _publication} =
        Publishing.publish_project(
          built_project.project,
          pub_description,
          state.current_author.id
        )

      # No longer automatically apply updates to sections
      # Use the update directive instead
      # Also no longer storing publications in state - they're fetched when needed

      {:ok, state}
    rescue
      e ->
        {:error, "Failed to publish: #{Exception.message(e)}"}
    end
  end
end

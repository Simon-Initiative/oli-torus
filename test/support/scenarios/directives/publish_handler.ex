defmodule Oli.Scenarios.Directives.PublishHandler do
  @moduledoc """
  Handles publish_changes directives to apply operations and publish projects.
  """

  alias Oli.Scenarios.DirectiveTypes.PublishChangesDirective
  alias Oli.Scenarios.{Engine, Ops}
  alias Oli.Publishing

  def handle(%PublishChangesDirective{target: target_name, ops: ops, description: description}, state) do
    try do
      # Get the target project
      built_project = Engine.get_project(state, target_name) ||
        raise "Project '#{target_name}' not found"

      # Apply operations if any
      {major?, updated_project} = if ops && Enum.any?(ops) do
        Ops.apply_ops!(built_project, ops)
      else
        {false, built_project}
      end

      # Update the project in state
      state = Engine.put_project(state, target_name, updated_project)

      # Publish the changes
      pub_description = description || if major?, do: "major update", else: "minor update"

      {:ok, _publication} = Publishing.publish_project(
        updated_project.project,
        pub_description,
        state.current_author.id
      )

      # No longer automatically apply updates to sections
      # Use the update directive instead
      # Also no longer storing publications in state - they're fetched when needed

      {:ok, state}
    rescue
      e ->
        {:error, "Failed to publish changes: #{Exception.message(e)}"}
    end
  end
end

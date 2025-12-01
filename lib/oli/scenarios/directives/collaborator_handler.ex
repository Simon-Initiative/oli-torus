defmodule Oli.Scenarios.Directives.CollaboratorHandler do
  @moduledoc """
  Handles collaborator directives to add an author as a collaborator to a project.
  """

  alias Oli.Scenarios.DirectiveTypes.CollaboratorDirective
  alias Oli.Scenarios.Engine
  alias Oli.Authoring.Collaborators
  alias Oli.Accounts.Author

  def handle(%CollaboratorDirective{user: user_name, project: project_name}, state) do
    try do
      user =
        Engine.get_user(state, user_name) ||
          raise "User '#{user_name}' not found in scenario state"

      unless match?(%Author{}, user) do
        raise "User '#{user_name}' is not an author and cannot be added as collaborator"
      end

      built_project =
        Engine.get_project(state, project_name) ||
          raise "Project '#{project_name}' not found in scenario state"

      case Collaborators.add_collaborator(user, built_project.project) do
        {:ok, _author_project} ->
          {:ok, state}

        {:error, reason} ->
          raise "Failed to add collaborator: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error, "Failed to add collaborator '#{user_name}' to '#{project_name}': #{Exception.message(e)}"}
    end
  end
end

defmodule Oli.Scenarios.Directives.CollaboratorHandler do
  @moduledoc """
  Handles collaborator directives to add an author as a collaborator to a project.
  """

  alias Oli.Scenarios.DirectiveTypes.CollaboratorDirective
  alias Oli.Scenarios.Engine
  alias Oli.Authoring.Collaborators
  alias Oli.Accounts.Author
  alias Oli.Accounts
  alias Oli.Repo
  alias Oli.Accounts.User

  def handle(
        %CollaboratorDirective{user: user_name, project: project_name, email: email_override},
        state
      ) do
    try do
      email = email_override || "#{user_name}@example.com"

      user =
        Engine.get_user(state, user_name) ||
          fetch_user_or_author(email) ||
          raise "User '#{user_name}' not found (state or DB)"

      author =
        cond do
          match?(%Author{}, user) ->
            user

          match?(%User{}, user) and not is_nil(user.author_id) ->
            Accounts.get_author!(user.author_id)

          true ->
            raise "User '#{user_name}' is not an author and cannot be added as collaborator"
        end

      built_project =
        Engine.get_project(state, project_name) ||
          raise "Project '#{project_name}' not found in scenario state"

      case Collaborators.add_collaborator(author, built_project.project) do
        {:ok, _author_project} ->
          {:ok, state}

        {:error, reason} ->
          raise "Failed to add collaborator: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error,
         "Failed to add collaborator '#{user_name}' to '#{project_name}': #{Exception.message(e)}"}
    end
  end

  defp fetch_user_or_author(email) do
    Accounts.get_author_by_email(email) || Repo.get_by(User, email: email)
  end
end

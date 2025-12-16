defmodule Oli.Scenarios.Directives.EnrollmentHandler do
  @moduledoc """
  Handles enrollment directives for adding users to sections.
  """

  alias Oli.Scenarios.DirectiveTypes.EnrollDirective
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.Repo
  alias Lti_1p3.Roles.ContextRoles

  def handle(
        %EnrollDirective{
          user: user_name,
          section: section_name,
          role: role,
          email: email_override
        },
        state
      ) do
    try do
      # Get user from state
      email = email_override || "#{user_name}@example.com"

      user =
        Engine.get_user(state, user_name) ||
          Repo.get_by(User, email: email) ||
          case Accounts.get_author_by_email(email) do
            %Author{id: author_id} ->
              Repo.get_by(User, author_id: author_id)

            _ ->
              nil
          end ||
          raise "User '#{user_name}' not found"

      # Get section from state
      section =
        Engine.get_section(state, section_name) ||
          raise "Section '#{section_name}' not found"

      # Enroll user in section with appropriate role
      context_role =
        case role do
          :instructor ->
            ContextRoles.get_role(:context_instructor)

          :student ->
            ContextRoles.get_role(:context_learner)

          _ ->
            raise "Unknown enrollment role: #{role}"
        end

      # Perform actual enrollment
      case normalize_enroll_response(Sections.enroll([user.id], section.id, [context_role])) do
        {:ok, []} ->
          raise "Enrollment returned an empty list for section '#{section_name}' and user '#{user_name}'"

        {:ok, _non_empty} ->
          {:ok, state}

        {:error, reason} ->
          raise "Enrollment failed: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error, "Failed to enroll '#{user_name}' in '#{section_name}': #{Exception.message(e)}"}
    end
  end

  # Normalize the variety of shapes Sections.enroll/4 can return
  defp normalize_enroll_response({:ok, {:ok, enrollments}}), do: {:ok, enrollments}
  defp normalize_enroll_response({:ok, enrollments}), do: {:ok, enrollments}
  defp normalize_enroll_response({:error, reason}), do: {:error, reason}
  defp normalize_enroll_response(other), do: {:error, {:unexpected_response, other}}
end

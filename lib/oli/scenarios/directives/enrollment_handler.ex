defmodule Oli.Scenarios.Directives.EnrollmentHandler do
  @moduledoc """
  Handles enrollment directives for adding users to sections.
  """

  alias Oli.Scenarios.DirectiveTypes.EnrollDirective
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  def handle(%EnrollDirective{user: user_name, section: section_name, role: role}, state) do
    try do
      # Get user from state
      user =
        Engine.get_user(state, user_name) ||
          raise "User '#{user_name}' not found"

      # Get section from state
      section =
        Engine.get_section(state, section_name) ||
          raise "Section '#{section_name}' not found"

      # Enroll user in section with appropriate role
      context_role = case role do
        :instructor ->
          ContextRoles.get_role(:context_instructor)

        :student ->
          ContextRoles.get_role(:context_learner)

        _ ->
          raise "Unknown enrollment role: #{role}"
      end

      # Perform actual enrollment
      case Sections.enroll([user.id], section.id, [context_role]) do
        {:ok, _enrollments} ->
          {:ok, state}
        
        {:error, reason} ->
          raise "Enrollment failed: #{inspect(reason)}"
      end
    rescue
      e ->
        {:error, "Failed to enroll '#{user_name}' in '#{section_name}': #{Exception.message(e)}"}
    end
  end
end

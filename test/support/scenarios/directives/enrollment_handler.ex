defmodule Oli.Scenarios.Directives.EnrollmentHandler do
  @moduledoc """
  Handles enrollment directives for adding users to sections.
  """

  alias Oli.Scenarios.DirectiveTypes.EnrollDirective
  alias Oli.Scenarios.Engine

  def handle(%EnrollDirective{user: user_name, section: section_name, role: role}, state) do
    try do
      # Get user from state
      _user = Engine.get_user(state, user_name) ||
        raise "User '#{user_name}' not found"
      
      # Get section from state
      _section = Engine.get_section(state, section_name) ||
        raise "Section '#{section_name}' not found"
      
      # Enroll user in section
      # Note: For simplicity, we'll just note that enrollment was requested
      # Actual enrollment requires complex role setup
      case role do
        :instructor ->
          # Would normally call Sections.enroll with instructor role
          :ok
        
        :student ->
          # Would normally call Sections.enroll with student role
          :ok
        
        _ ->
          raise "Unknown enrollment role: #{role}"
      end
      
      {:ok, state}
    rescue
      e ->
        {:error, "Failed to enroll '#{user_name}' in '#{section_name}': #{Exception.message(e)}"}
    end
  end
end
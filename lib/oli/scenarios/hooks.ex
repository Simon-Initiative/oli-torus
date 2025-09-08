defmodule Oli.Scenarios.Hooks do
  @moduledoc """
  Collection of hook functions that can be called from scenario YAML files.

  These functions demonstrate the power of the hook directive, allowing
  scenarios to perform custom operations like data injection, corruption,
  state manipulation, and other testing utilities.

  All hook functions must:
  - Accept exactly one argument: the ExecutionState
  - Return an updated ExecutionState
  """

  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Resources
  require Logger

  @doc """
  Logs the current state for debugging purposes.
  Useful for inspecting state during scenario execution.
  """
  def log_state(%ExecutionState{} = state) do
    Logger.info("Current scenario state:")
    Logger.info("  Projects: #{map_size(state.projects)}")
    Logger.info("  Sections: #{map_size(state.sections)}")
    Logger.info("  Products: #{map_size(state.products)}")
    Logger.info("  Users: #{map_size(state.users)}")
    Logger.info("  Activities: #{map_size(state.activities)}")

    state
  end

  @doc """
  Injects corrupted data into a project's page content.
  Useful for testing error handling and validation.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.corrupt_page_content/1"
  """
  def corrupt_page_content(%ExecutionState{} = state) do
    # Get the first project
    case state.projects |> Map.values() |> List.first() do
      nil ->
        Logger.warning("No projects found to corrupt")
        state

      built_project ->
        # Get the first page revision
        case built_project.rev_by_title
             |> Map.values()
             |> Enum.find(&(&1.resource_type_id == 1)) do
          nil ->
            Logger.warning("No pages found to corrupt")
            state

          page_revision ->
            Logger.info("Corrupting page: #{page_revision.title}")

            # Create corrupted content
            corrupted_content = %{
              "model" => [
                %{
                  "type" => "p",
                  "children" => [
                    %{
                      "text" => "CORRUPTED DATA: #{:rand.uniform(999_999)}",
                      "invalid_field" => "This shouldn't be here"
                    }
                  ],
                  "corrupted" => true
                }
              ]
            }

            # Update the revision (this is direct manipulation for testing)
            {:ok, _} = Resources.update_revision(page_revision, %{content: corrupted_content})

            state
        end
    end
  end

  @doc """
  Adds a custom flag to the state for conditional testing.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.set_test_flag/1"
  """
  def set_test_flag(%ExecutionState{} = state) do
    # Add a custom field to track that this hook was called
    Map.put(state, :test_flags, Map.get(state, :test_flags, %{}) |> Map.put(:hook_executed, true))
  end

  @doc """
  Simulates a delay in scenario execution.
  Useful for testing timeout behaviors.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.delay_execution/1"
  """
  def delay_execution(%ExecutionState{} = state) do
    Logger.info("Delaying execution for 1 second...")
    Process.sleep(1000)
    state
  end

  @doc """
  Creates multiple test users programmatically.
  Demonstrates how hooks can perform batch operations.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.create_bulk_users/1"
  """
  def create_bulk_users(%ExecutionState{} = state) do
    Logger.info("Creating 5 test users...")

    users =
      for i <- 1..5 do
        {:ok, user} =
          Oli.Accounts.create_guest_user(%{
            guest: false,
            email: "bulk_user_#{i}@test.edu",
            given_name: "Bulk",
            family_name: "User#{i}",
            sub: "bulk_user_#{i}_#{System.unique_integer([:positive])}"
          })

        {"bulk_user_#{i}", user}
      end

    updated_users = Map.merge(state.users, Map.new(users))
    %{state | users: updated_users}
  end

  @doc """
  Validates that certain conditions are met in the state.
  Raises an error if validation fails.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.validate_state/1"
  """
  def validate_state(%ExecutionState{} = state) do
    cond do
      map_size(state.projects) == 0 ->
        raise "Validation failed: No projects in state"

      map_size(state.sections) == 0 ->
        raise "Validation failed: No sections in state"

      true ->
        Logger.info("State validation passed")
        state
    end
  end

  @doc """
  Clears all activities from the state.
  Useful for testing scenarios where activities need to be rebuilt.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.clear_activities/1"
  """
  def clear_activities(%ExecutionState{} = state) do
    Logger.info("Clearing all activities from state")
    %{state | activities: %{}, activity_virtual_ids: %{}}
  end

  @doc """
  Modifies publication settings for all projects.
  Demonstrates direct manipulation of project data.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.modify_publications/1"
  """
  def modify_publications(%ExecutionState{} = state) do
    Logger.info("Modifying publication settings...")

    updated_projects =
      state.projects
      |> Enum.map(fn {name, built_project} ->
        # Add a custom description to the working publication
        if built_project.working_pub do
          {:ok, _} =
            Oli.Publishing.update_publication(
              built_project.working_pub,
              %{description: "Modified by hook at #{DateTime.utc_now()}"}
            )
        end

        {name, built_project}
      end)
      |> Map.new()

    %{state | projects: updated_projects}
  end

  @doc """
  Injects a specific error condition for testing error handling.

  Example usage in YAML:
    - hook:
        function: "Oli.Scenarios.Hooks.inject_error/1"
  """
  def inject_error(%ExecutionState{} = state) do
    # This intentionally creates an error condition that can be tested
    Map.put(state, :error_injected, %{
      type: :test_error,
      message: "Intentional error injected for testing",
      timestamp: DateTime.utc_now()
    })
  end
end

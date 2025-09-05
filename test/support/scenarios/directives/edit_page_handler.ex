defmodule Oli.Scenarios.Directives.EditPageHandler do
  @moduledoc """
  Handles edit_page directives for editing existing page content from TorusDoc YAML.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, EditPageDirective}
  alias Oli.TorusDoc.PageConverter
  alias Oli.Scenarios.Directives.ActivityProcessor

  @doc """
  Edits an existing page's content using TorusDoc YAML.

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%EditPageDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, author} <- validate_author(state.current_author),
         {:ok, project_name} <- validate_project_name(directive.project),
         {:ok, built_project} <- get_project(project_name, state),
         {:ok, page_revision} <- get_page_revision(built_project, directive.page),
         # Process inline activities and virtual_id references
         {:ok, processed_content, updated_state} <- process_activities(
           directive.content,
           project_name,
           built_project,
           author,
           state
         ),
         {:ok, page_json} <- parse_and_convert_page(processed_content),
         {:ok, new_revision} <- edit_page(built_project, page_revision, author, page_json) do
      
      # Update the rev_by_title mapping with the new revision
      updated_built_project = update_revision_mapping(built_project, directive.page, new_revision)
      
      # Update the state with the updated project and activity mappings
      updated_projects = Map.put(updated_state.projects, project_name, updated_built_project)
      {:ok, %{updated_state | projects: updated_projects}}
    else
      {:error, reason} ->
        {:error, "Failed to edit page '#{directive.page}': #{inspect(reason)}"}
    end
  end

  # Validate that an author is available
  defp validate_author(nil) do
    {:error,
     "No author available. The Engine should provide a default author, or you can create one with a 'user' directive"}
  end

  defp validate_author(author), do: {:ok, author}

  # Validate that project name is provided
  defp validate_project_name(nil), do: {:error, "Project name is required"}
  defp validate_project_name(name) when is_binary(name), do: {:ok, name}
  defp validate_project_name(_), do: {:error, "Project name must be a string"}

  # Get project from state
  defp get_project(project_name, state) do
    case Map.get(state.projects, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  # Get page revision by title from built project
  defp get_page_revision(built_project, page_title) do
    # First try to find by the given title
    case Map.get(built_project.rev_by_title, page_title) do
      nil ->
        # Page not found by the given title - it might have been renamed
        # Try to find a page by checking all revisions to see if any has a matching resource_id
        # that we previously knew by a different title
        # For now, return error - in a real scenario we'd need to track resource_id mappings
        {:error, "Page '#{page_title}' not found in project"}

      revision ->
        # Use the revision from the built_project state directly
        # In test scenarios, this is the most up-to-date version
        {:ok, revision}
    end
  end

  # Process activities in the page content
  defp process_activities(content, project_name, built_project, author, state) do
    ActivityProcessor.process_page_content(content, project_name, built_project, author, state)
  end
  
  # Parse TorusDoc YAML content and convert to Torus JSON
  defp parse_and_convert_page(content) when is_binary(content) do
    # Add the type field if not present in the YAML
    yaml_with_type = ensure_page_type(content)

    case PageConverter.from_yaml(yaml_with_type) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to parse page YAML: #{reason}"}
    end
  end

  defp parse_and_convert_page(_), do: {:error, "Page content must be a YAML string"}

  # Ensure the page YAML has the correct type field
  defp ensure_page_type(yaml_content) do
    # Check if type: page is already specified at the root level
    # We need to check if the YAML starts with type: page or has it at the root level
    lines = String.split(yaml_content, "\n")

    # Check if any of the first few non-empty lines has type: page
    has_page_type =
      lines
      # Check first 5 lines
      |> Enum.take(5)
      |> Enum.any?(fn line ->
        String.trim(line) == "type: page" || String.trim(line) == "type: \"page\""
      end)

    if has_page_type do
      yaml_content
    else
      # Prepend the type to the YAML
      "type: page\n#{yaml_content}"
    end
  end

  # Edit the page - for test scenarios, directly update the revision
  defp edit_page(_built_project, page_revision, author, page_json) do
    # In test scenarios, we directly update the revision structure
    # instead of going through PageEditor which requires database records
    
    # Create an updated revision with the new content
    updated_revision = %{page_revision |
      title: page_json["title"] || page_revision.title,
      content: page_json["content"],
      graded: page_json["isGraded"] || false,
      author_id: author.id,
      updated_at: DateTime.utc_now()
    }
    
    {:ok, updated_revision}
  end

  # Update the rev_by_title mapping with the new revision
  defp update_revision_mapping(built_project, page_title, new_revision) do
    # Also update the title in case it changed
    old_title = page_title
    new_title = new_revision.title

    updated_rev_by_title = 
      if old_title == new_title do
        # Title didn't change, just update the revision
        Map.put(built_project.rev_by_title, page_title, new_revision)
      else
        # Title changed, but we need to keep BOTH mappings:
        # 1. The original title should still point to the revision (for subsequent edits)
        # 2. The new title should also point to the revision (for lookups by current title)
        built_project.rev_by_title
        |> Map.put(old_title, new_revision)  # Keep original title mapping
        |> Map.put(new_title, new_revision)  # Add new title mapping
      end

    %{built_project | rev_by_title: updated_rev_by_title}
  end
end

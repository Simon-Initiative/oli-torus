defmodule Oli.Scenarios.Directives.UpdateHandler do
  @moduledoc """
  Handles update directives to apply publication updates to sections.
  """

  alias Oli.Scenarios.DirectiveTypes.UpdateDirective
  alias Oli.Scenarios.Engine

  def handle(%UpdateDirective{from: project_name, to: section_name}, state) do
    try do
      # Get the section
      section =
        Engine.get_section(state, section_name) ||
          raise "Section '#{section_name}' not found"

      # Get the project
      built_project =
        Engine.get_project(state, project_name) ||
          raise "Project '#{project_name}' not found"

      # Get the latest published publication for this project
      latest_publication =
        Oli.Publishing.get_latest_published_publication_by_slug(built_project.project.slug)

      if is_nil(latest_publication) do
        raise "No published publications found for project '#{project_name}'"
      end

      # Verify the section is from this project
      if section.base_project_id != built_project.project.id do
        raise "Section '#{section_name}' is not based on project '#{project_name}'"
      end

      # Apply the publication update to the section
      result =
        Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # Check if result looks like an error
      case result do
        {:error, reason} ->
          raise "Failed to apply update: #{inspect(reason)}"

        {:ok, updated_section} ->
          # Clear any caches and force reload
          Oli.Delivery.Sections.SectionCache.clear(updated_section.slug)

          # Small delay to ensure all async processing is complete
          Process.sleep(100)

          refreshed_section = Oli.Delivery.Sections.get_section!(updated_section.id)

          # Update the section in state with the refreshed section
          updated_state = Engine.put_section(state, section_name, refreshed_section)
          {:ok, updated_state}

        _ ->
          # Clear any caches and force reload
          Oli.Delivery.Sections.SectionCache.clear(section.slug)
          updated_section = Oli.Delivery.Sections.get_section!(section.id)

          updated_state = Engine.put_section(state, section_name, updated_section)
          {:ok, updated_state}
      end
    rescue
      e ->
        {:error,
         "Failed to apply update from '#{project_name}' to '#{section_name}': #{Exception.message(e)}"}
    end
  end
end

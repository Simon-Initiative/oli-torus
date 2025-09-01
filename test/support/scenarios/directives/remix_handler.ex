defmodule Oli.Scenarios.Directives.RemixHandler do
  @moduledoc """
  Handles remix directives for copying content from projects into sections.
  Remixes content from a source project into a target section's hierarchy.
  """

  alias Oli.Scenarios.DirectiveTypes.RemixDirective
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.{Hierarchy, Sections}
  alias Oli.Delivery.Sections.SectionCache

  def handle(
        %RemixDirective{from: from, resource: resource_title, section: section_name, to: to},
        %ExecutionState{} = state
      ) do
    try do
      # Get source project
      source_project =
        Engine.get_project(state, from) ||
          raise "Source project '#{from}' not found"

      # Get the target section or product
      section =
        case Engine.get_product(state, section_name) do
          nil ->
            Engine.get_section(state, section_name) ||
              raise "Section or product '#{section_name}' not found"

          product ->
            product
        end

      # Get the resource ID to remix from the source project
      resource_id =
        source_project.id_by_title[resource_title] ||
          raise "Resource '#{resource_title}' not found in source project '#{from}'"

      # Get the latest published publication for the source project
      publication =
        case Publishing.get_latest_published_publication_by_slug(source_project.project.slug) do
          nil ->
            # If no published publication exists, publish one
            {:ok, pub} =
              Publishing.publish_project(
                source_project.project,
                "Auto-published for remix",
                state.current_author.id
              )

            pub

          pub ->
            pub
        end

      # Get the section's current hierarchy as HierarchyNode structs
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # Find the target container in the hierarchy
      # Special case: "root" refers to the top-level container
      target_container =
        if to == "root" do
          hierarchy
        else
          find_node_by_title(hierarchy, to)
        end

      if !target_container do
        raise "Target container '#{to}' not found in section hierarchy"
      end

      # Get published resources for this publication
      published_resources_by_resource_id =
        Publishing.get_published_resources_for_publications([publication.id])

      # Create selection tuple like RemixUI does
      selection = [{publication.id, resource_id}]

      # Use Hierarchy.add_materials_to_hierarchy to properly add the content
      updated_hierarchy =
        Hierarchy.add_materials_to_hierarchy(
          hierarchy,
          target_container,
          selection,
          published_resources_by_resource_id
        )
        |> Hierarchy.finalize()

      # Get current pinned project publications for the section
      pinned_project_publications = Sections.get_pinned_project_publications(section.id)

      # Update pinned publications to include the source project if not already there
      updated_pinned_publications =
        if Map.has_key?(pinned_project_publications, source_project.project.id) do
          pinned_project_publications
        else
          Map.put(pinned_project_publications, source_project.project.id, publication)
        end

      # Rebuild the section curriculum with the modified hierarchy
      Sections.rebuild_section_curriculum(section, updated_hierarchy, updated_pinned_publications)

      # Clear cache and reload section
      SectionCache.clear(section.slug)
      Process.sleep(100)

      refreshed_section = Sections.get_section!(section.id)

      # Update state with the refreshed section or product
      updated_state =
        case Engine.get_product(state, section_name) do
          nil ->
            # It's a section
            Engine.put_section(state, section_name, refreshed_section)

          _product ->
            # It's a product - update as product
            Engine.put_product(state, section_name, refreshed_section)
        end

      {:ok, updated_state}
    rescue
      e ->
        {:error,
         "Failed to remix '#{resource_title}' from '#{from}' to '#{to}': #{Exception.message(e)}"}
    end
  end

  defp find_node_by_title(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    if node.revision && node.revision.title == title do
      node
    else
      Enum.find_value(node.children || [], fn child ->
        find_node_by_title(child, title)
      end)
    end
  end

  defp find_node_by_title(_, _), do: nil
end

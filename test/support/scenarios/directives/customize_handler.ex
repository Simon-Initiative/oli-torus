defmodule Oli.Scenarios.Directives.CustomizeHandler do
  @moduledoc """
  Handles customize directives that apply operations to section curriculum.
  """

  alias Oli.Scenarios.DirectiveTypes.{CustomizeDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.{Hierarchy, Sections}
  alias Oli.Delivery.Sections.SectionCache
  alias Oli.Publishing.DeliveryResolver

  def handle(%CustomizeDirective{to: to, ops: ops}, %ExecutionState{} = state) do
    # First check if it's a product, then check sections
    section_or_product =
      case Engine.get_product(state, to) do
        nil ->
          Engine.get_section(state, to)

        product ->
          product
      end

    case section_or_product do
      nil ->
        {:error, "Section or product '#{to}' not found"}

      section ->
        try do
          # Get the section's current hierarchy as HierarchyNode structs
          hierarchy = DeliveryResolver.full_hierarchy(section.slug)

          # Get pinned project publications for the section
          project_publications = Sections.get_pinned_project_publications(section.id)

          # Apply operations to the hierarchy
          updated_hierarchy = apply_ops_to_hierarchy(hierarchy, ops, section, state)

          # Finalize the hierarchy to ensure proper structure
          finalized_hierarchy = Hierarchy.finalize(updated_hierarchy)

          # Rebuild the section curriculum with the modified hierarchy
          Sections.rebuild_section_curriculum(section, finalized_hierarchy, project_publications)

          # Clear cache and reload section
          SectionCache.clear(section.slug)
          # Small delay to ensure async processing completes
          Process.sleep(100)

          refreshed_section = Sections.get_section!(section.id)

          # Update state with the refreshed section or product
          updated_state =
            case Engine.get_product(state, to) do
              nil ->
                # It's a section
                Engine.put_section(state, to, refreshed_section)

              _product ->
                # It's a product - update as product
                Engine.put_product(state, to, refreshed_section)
            end

          {:ok, updated_state}
        rescue
          e ->
            {:error, "Failed to customize '#{to}': #{inspect(e)}"}
        end
    end
  end

  defp apply_ops_to_hierarchy(hierarchy, ops, section, state) do
    Enum.reduce(ops, hierarchy, fn op, acc_hierarchy ->
      apply_op(op, acc_hierarchy, section, state)
    end)
  end

  defp apply_op(%{"remove" => %{"from" => title}}, hierarchy, _section, _state) do
    # Find the node with the given title
    node_to_remove = find_node_by_title(hierarchy, title)

    if node_to_remove do
      # Remove the node from the hierarchy using its uuid
      Hierarchy.find_and_remove_node(hierarchy, node_to_remove.uuid)
    else
      raise "Resource '#{title}' not found in section hierarchy"
    end
  end

  defp apply_op(%{"reorder" => params}, hierarchy, _section, _state) do
    from_title = params["from"]
    before_title = params["before"]
    after_title = params["after"]

    # Find the node to reorder
    source_node = find_node_by_title(hierarchy, from_title)

    if !source_node do
      raise "Resource '#{from_title}' not found in section hierarchy"
    end

    # Find the parent container of the source node
    parent_container = find_parent_of_node(hierarchy, source_node.uuid)

    if !parent_container do
      raise "Could not find parent container for '#{from_title}'"
    end

    # Get the current index of the source node
    source_index =
      Enum.find_index(parent_container.children, fn child ->
        child.uuid == source_node.uuid
      end)

    # Calculate the destination index based on before/after
    destination_index =
      cond do
        before_title ->
          target_node = find_node_by_title(hierarchy, before_title)

          if !target_node do
            raise "Target resource '#{before_title}' not found"
          end

          # Find index of the before node in the parent's children
          case Enum.find_index(parent_container.children, fn child ->
                 child.uuid == target_node.uuid
               end) do
            nil -> raise "Target '#{before_title}' is not a sibling of '#{from_title}'"
            # Insert at the same index to go before
            idx -> idx
          end

        after_title ->
          target_node = find_node_by_title(hierarchy, after_title)

          if !target_node do
            raise "Target resource '#{after_title}' not found"
          end

          # Find index of the after node in the parent's children
          case Enum.find_index(parent_container.children, fn child ->
                 child.uuid == target_node.uuid
               end) do
            nil -> raise "Target '#{after_title}' is not a sibling of '#{from_title}'"
            # Insert after by going to next index
            idx -> idx + 1
          end

        true ->
          raise "Reorder operation requires either 'before' or 'after' attribute"
      end

    # Reorder the children
    updated_parent =
      Hierarchy.reorder_children(
        parent_container,
        source_node,
        source_index,
        destination_index
      )

    # Update the hierarchy with the reordered parent
    Hierarchy.find_and_update_node(hierarchy, updated_parent)
  end

  # Handle other operations in the future
  defp apply_op(op, _hierarchy, _section, _state) do
    raise "Unknown customize operation: #{inspect(op)}"
  end

  defp find_node_by_title(hierarchy, title) do
    find_node_by_title_r(hierarchy, title)
  end

  defp find_node_by_title_r(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    # Check if this node has the title we're looking for
    if node.revision && node.revision.title == title do
      node
    else
      # Search in children
      Enum.find_value(node.children || [], fn child ->
        find_node_by_title_r(child, title)
      end)
    end
  end

  defp find_node_by_title_r(_, _), do: nil

  defp find_parent_of_node(hierarchy, target_uuid) do
    find_parent_of_node_r(hierarchy, target_uuid)
  end

  defp find_parent_of_node_r(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, target_uuid) do
    # Check if any of this node's children have the target uuid
    if Enum.any?(node.children || [], fn child -> child.uuid == target_uuid end) do
      node
    else
      # Search in children recursively
      Enum.find_value(node.children || [], fn child ->
        find_parent_of_node_r(child, target_uuid)
      end)
    end
  end

  defp find_parent_of_node_r(_, _), do: nil
end

defmodule Oli.Scenarios.Directives.Assert.StructureAssertion do
  @moduledoc """
  Handles structure assertions for projects and sections.
  """

  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.Types.Node
  alias Oli.Publishing.{DeliveryResolver, AuthoringResolver}
  alias Oli.Resources.ResourceType

  @doc """
  Asserts that the structure of a project or section matches the expected structure.
  """
  def assert(%AssertDirective{structure: structure_data}, state) when is_map(structure_data) do
    to_name = structure_data.to
    expected_structure = structure_data.root

    # Determine if target is a project or section
    {target_type, target} = get_target(state, to_name)

    # Get the actual structure
    actual_structure =
      case target_type do
        :section ->
          get_section_structure(target)

        :project ->
          get_project_structure(target)
      end

    # Verify the structure
    verification_result = verify_structure(to_name, expected_structure, actual_structure)

    {:ok, state, verification_result}
  end

  def assert(%AssertDirective{structure: nil}, state), do: {:ok, state, nil}

  defp get_target(state, name) do
    # Check for product first
    case Engine.get_product(state, name) do
      nil ->
        # Then check for section
        case Engine.get_section(state, name) do
          nil ->
            # Finally check for project
            case Engine.get_project(state, name) do
              nil -> raise "Target '#{name}' not found"
              project -> {:project, project}
            end

          section ->
            {:section, section}
        end

      product ->
        # Products are sections behind the scenes
        {:section, product}
    end
  end

  defp get_section_structure(section) do
    # Get the full hierarchy for the section - always fetch fresh from DB
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    # Convert the hierarchy to our Node structure for comparison
    convert_hierarchy_to_node(hierarchy)
  end

  defp get_project_structure(built_project) do
    # Get fresh root revision from the database to avoid stale data
    fresh_root_revision =
      AuthoringResolver.from_resource_id(
        built_project.project.slug,
        built_project.root.revision.resource_id
      )

    # Convert to Node structure
    %Node{
      type: :container,
      title: "root",
      children: convert_children_ids_to_nodes(fresh_root_revision.children, built_project)
    }
  end

  defp convert_hierarchy_to_node(%Oli.Delivery.Hierarchy.HierarchyNode{} = hierarchy) do
    # HierarchyNode is a struct, use dot notation
    # Get resource type - prefer revision's resource_type_id as it's always populated
    resource_type_id =
      cond do
        hierarchy.revision && hierarchy.revision.resource_type_id ->
          hierarchy.revision.resource_type_id

        hierarchy.section_resource && hierarchy.section_resource.resource_type_id ->
          hierarchy.section_resource.resource_type_id

        true ->
          # For root nodes without revision or section_resource, assume container
          ResourceType.id_for_container()
      end

    revision = hierarchy.revision
    children = hierarchy.children || []

    title =
      cond do
        revision && revision.title ->
          revision.title

        hierarchy.section_resource && hierarchy.section_resource.title ->
          hierarchy.section_resource.title

        true ->
          "root"
      end

    page_type_id = ResourceType.id_for_page()

    %Node{
      type: if(resource_type_id == page_type_id, do: :page, else: :container),
      title: title,
      children: Enum.map(children, &convert_hierarchy_to_node/1)
    }
  end

  defp convert_hierarchy_to_node(hierarchy) when is_map(hierarchy) do
    # Fallback for map-based hierarchies (shouldn't happen with DeliveryResolver)
    resource_type_id = hierarchy[:resource_type_id] || hierarchy["resource_type_id"]
    revision = hierarchy[:revision] || hierarchy["revision"]
    children = hierarchy[:children] || hierarchy["children"] || []

    title =
      if is_map(revision) do
        revision[:title] || revision["title"]
      else
        hierarchy[:title] || hierarchy["title"] || "Unknown"
      end

    page_type_id = ResourceType.id_for_page()

    %Node{
      type: if(resource_type_id == page_type_id, do: :page, else: :container),
      title: title,
      children: Enum.map(children, &convert_hierarchy_to_node/1)
    }
  end

  defp convert_children_ids_to_nodes(nil, _built_project), do: []

  defp convert_children_ids_to_nodes(children_ids, built_project) do
    Enum.map(children_ids, fn child_id ->
      # Find the revision for this child ID
      revision = find_revision_by_id(child_id, built_project)

      if revision do
        is_page = revision.resource_type_id == ResourceType.id_for_page()

        %Node{
          type: if(is_page, do: :page, else: :container),
          title: revision.title,
          children:
            if(is_page,
              do: [],
              else: convert_children_ids_to_nodes(revision.children, built_project)
            )
        }
      else
        nil
      end
    end)
    |> Enum.filter(& &1)
  end

  defp find_revision_by_id(resource_id, built_project) do
    # Get fresh revision from database to avoid stale data
    AuthoringResolver.from_resource_id(built_project.project.slug, resource_id)
  end

  defp verify_structure(to_name, expected, actual) do
    try do
      # Compare the structures
      compare_nodes(expected, actual)

      %VerificationResult{
        to: to_name,
        passed: true,
        message: "Structure matches expected",
        expected: expected,
        actual: actual
      }
    rescue
      e ->
        %VerificationResult{
          to: to_name,
          passed: false,
          message: Exception.message(e),
          expected: expected,
          actual: actual
        }
    end
  end

  defp compare_nodes(%Node{} = expected, %Node{} = actual) do
    # Special case: root containers might have different titles
    # "root" in expected should match "Root Container" or any root container
    unless is_root_match?(expected.title, actual.title) do
      if expected.title != actual.title do
        raise "Title mismatch: expected '#{expected.title}', got '#{actual.title}'"
      end
    end

    # Compare types
    if expected.type != actual.type do
      raise "Type mismatch for '#{expected.title}': expected #{expected.type}, got #{actual.type}"
    end

    # Compare children count
    expected_children = expected.children || []
    actual_children = actual.children || []

    if length(expected_children) != length(actual_children) do
      raise "Children count mismatch for '#{expected.title}': expected #{length(expected_children)}, got #{length(actual_children)}"
    end

    # Recursively compare children
    Enum.zip(expected_children, actual_children)
    |> Enum.each(fn {expected_child, actual_child} ->
      compare_nodes(expected_child, actual_child)
    end)

    :ok
  end

  defp is_root_match?("root", actual_title) do
    # Accept various forms of root container titles
    actual_title in ["Root Container", "root", "Root", "ROOT"]
  end

  defp is_root_match?(_, _), do: false
end

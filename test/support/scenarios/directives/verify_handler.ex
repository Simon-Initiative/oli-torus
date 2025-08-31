defmodule Oli.Scenarios.Directives.VerifyHandler do
  @moduledoc """
  Handles verify directives to assert expected structures.
  """

  alias Oli.Scenarios.DirectiveTypes.{VerifyDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.Types.Node
  alias Oli.Delivery.Hierarchy

  def handle(
        %VerifyDirective{to: to_name, structure: expected_structure, assertions: assertions},
        state
      ) do
    try do
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

      # Perform structure verification if expected structure is provided
      verification_result =
        if expected_structure do
          verify_structure(to_name, target_type, expected_structure, actual_structure)
        else
          %VerificationResult{
            to: to_name,
            passed: true,
            message: "No structure verification specified"
          }
        end

      # Perform additional assertions if provided
      if assertions && Enum.any?(assertions) do
        # Would integrate with existing Assertions module
        # For now, just note that assertions were specified
      end

      {:ok, state, verification_result}
    rescue
      e ->
        {:error, "Failed to verify '#{to_name}': #{Exception.message(e)}"}
    end
  end

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
    # Get the full hierarchy for the section
    # Section should have a slug field
    hierarchy = Hierarchy.full_hierarchy(section)

    # Convert the hierarchy to our Node structure for comparison
    convert_hierarchy_to_node(hierarchy)
  end

  defp get_project_structure(built_project) do
    # Get the project's hierarchy from its root revision
    # The root revision already contains the children structure
    root_revision = built_project.root.revision

    # Convert to Node structure
    %Node{
      type: :container,
      title: "root",
      children: convert_children_ids_to_nodes(root_revision.children, built_project)
    }
  end

  defp convert_hierarchy_to_node(hierarchy) when is_map(hierarchy) do
    # Handle both atom and string keys
    resource_type_id = hierarchy[:resource_type_id] || hierarchy["resource_type_id"]
    revision = hierarchy[:revision] || hierarchy["revision"]
    children = hierarchy[:children] || hierarchy["children"] || []

    title =
      if is_map(revision) do
        revision[:title] || revision["title"]
      else
        # Sometimes the title might be directly in the hierarchy
        hierarchy[:title] || hierarchy["title"] || "Unknown"
      end

    page_type_id = Oli.Resources.ResourceType.id_for_page()

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
        is_page = revision.resource_type_id == Oli.Resources.ResourceType.id_for_page()

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
    # First find the title that corresponds to this resource_id
    matching_title =
      Enum.find_value(built_project.id_by_title, fn {title, id} ->
        if id == resource_id, do: title
      end)

    # Then get the revision for that title
    if matching_title do
      built_project.rev_by_title[matching_title]
    else
      nil
    end
  end

  defp verify_structure(to_name, _target_type, expected, actual) do
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

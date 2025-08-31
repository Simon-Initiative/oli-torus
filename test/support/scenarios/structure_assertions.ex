defmodule Oli.Scenarios.StructureAssertions do
  @moduledoc """
  Compares expected structure (from YAML) against actual hierarchy from section.
  """
  alias Oli.Scenarios.Types.Node
  import ExUnit.Assertions

  @doc """
  Assert that the actual hierarchy matches the expected structure.
  """
  def assert_structure_matches!(result, expected_root) when is_struct(expected_root, Node) do
    actual_root = result.final_hierarchy
    assert_node_matches!(expected_root, actual_root, [])
  end

  def assert_structure_matches!(_result, nil), do: :ok

  defp assert_node_matches!(%Node{type: :container, children: expected_children}, actual, path) do
    # For containers (including root), check children
    actual_children = Map.get(actual, :children, [])
    
    # Create a map of actual children by title for easier lookup (not currently used but may be useful for debugging)
    _actual_by_title = actual_children
    |> Enum.map(fn child -> {get_title(child), child} end)
    |> Map.new()
    
    # Check that we have the right number of children
    expected_count = length(expected_children)
    actual_count = length(actual_children)
    
    assert expected_count == actual_count,
      "At path #{format_path(path)}: Expected #{expected_count} children but found #{actual_count}. " <>
      "Expected: #{inspect(Enum.map(expected_children, & &1.title))}, " <>
      "Actual: #{inspect(Enum.map(actual_children, &get_title/1))}"
    
    # Check each expected child in order
    expected_children
    |> Enum.with_index()
    |> Enum.each(fn {expected_child, index} ->
      actual_child = Enum.at(actual_children, index)
      
      # Verify the title matches
      expected_title = expected_child.title
      actual_title = get_title(actual_child)
      
      assert expected_title == actual_title,
        "At path #{format_path(path)}, position #{index}: " <>
        "Expected '#{expected_title}' but found '#{actual_title}'"
      
      # Recursively check children if it's a container
      if expected_child.type == :container && expected_child.children != [] do
        assert_node_matches!(expected_child, actual_child, path ++ [expected_title])
      end
    end)
  end

  defp assert_node_matches!(%Node{type: :page, title: expected_title}, actual, path) do
    actual_title = get_title(actual)
    
    assert expected_title == actual_title,
      "At path #{format_path(path)}: Expected page '#{expected_title}' but found '#{actual_title}'"
  end

  defp get_title(node) do
    cond do
      # For hierarchy nodes with revision
      Map.has_key?(node, :revision) && node.revision ->
        node.revision.title
      
      # For nodes with direct title
      Map.has_key?(node, :title) ->
        node.title
      
      # Default
      true ->
        "Unknown"
    end
  end

  defp format_path([]), do: "root"
  defp format_path(path), do: "root > " <> Enum.join(path, " > ")

  @doc """
  Helper to compare just the titles at root level (less strict than full structure match).
  """
  def assert_root_titles_match!(result, expected_root) do
    expected_titles = Enum.map(expected_root.children, & &1.title)
    actual_titles = result.final_hierarchy.children |> Enum.map(&get_title/1)
    
    assert expected_titles == actual_titles,
      "Root titles don't match. Expected: #{inspect(expected_titles)}, Actual: #{inspect(actual_titles)}"
  end

  @doc """
  Creates a visual diff of the structures for debugging.
  """
  def structure_diff(expected_root, actual_hierarchy) do
    expected_lines = structure_to_lines(expected_root, 0)
    actual_lines = hierarchy_to_lines(actual_hierarchy, 0)
    
    """
    Expected Structure:
    #{Enum.join(expected_lines, "\n")}
    
    Actual Structure:
    #{Enum.join(actual_lines, "\n")}
    """
  end

  defp structure_to_lines(%Node{type: type, title: title, children: children}, indent) do
    prefix = String.duplicate("  ", indent)
    type_marker = if type == :container, do: "[C]", else: "[P]"
    
    lines = ["#{prefix}#{type_marker} #{title}"]
    
    child_lines = children
    |> Enum.flat_map(&structure_to_lines(&1, indent + 1))
    
    lines ++ child_lines
  end

  defp hierarchy_to_lines(node, indent) do
    prefix = String.duplicate("  ", indent)
    title = get_title(node)
    children = Map.get(node, :children, [])
    
    type_marker = if children == [], do: "[P]", else: "[C]"
    lines = ["#{prefix}#{type_marker} #{title}"]
    
    child_lines = children
    |> Enum.flat_map(&hierarchy_to_lines(&1, indent + 1))
    
    lines ++ child_lines
  end
end
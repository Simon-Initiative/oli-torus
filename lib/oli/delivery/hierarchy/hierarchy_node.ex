defmodule Oli.Delivery.Hierarchy.HierarchyNode do
  alias Oli.Delivery.Hierarchy.HierarchyNode

  @moduledoc """
  HierarchyNode is a generic in-memory representation of a node within a hierarchy. This struct
  is shared across authoring and delivery and allows generalized components to work in both.

  A hierarchy is a single root node which contains children. The children in a node are intended
  to be fully instantiated structs (as opposed to just identifiers. However during the process of
  instantiating the hierarchy, children may temporarily be set as an identifier until the full
  hierarchy is instantiated).

  The hierarchy node also has a "uuid" value which is used to uniquely identify the node within a
  hierarchy. This uuid is intended to be ephemeral and not expected to persist pass the lifecycle
  of a given in-memory hierarchy.
  """

  defstruct uuid: nil,
            numbering: nil,
            children: [],
            resource_id: nil,
            project_id: nil,
            revision: nil,
            section_resource: nil,
            ancestors: []

  @doc """
  Given a hierarchy node, this function "flattens" all nodes below into a list, in the order that
  a student would encounter the resources working linearly through a course.

  As an example, consider the followign hierarchy:

  --Unit 1
  ----Module 1
  ------Page A
  ------Page B
  --Unit 2
  ----Moudule 2
  ------Page C

  The above would be flattened to:
  Unit 1
  Module 1
  Page A
  Page B
  Unit 2
  Module 2
  Page C

  """
  def flatten(%HierarchyNode{} = root) do
    flatten_helper(root, [], [])
    |> Enum.reverse()
  end

  defp flatten_helper(%HierarchyNode{children: children}, flattened_nodes, current_ancestors) do
    Enum.reduce(children, flattened_nodes, fn node, acc ->
      node = %{node | ancestors: current_ancestors}

      case Oli.Resources.ResourceType.get_type_by_id(node.revision.resource_type_id) do
        "container" -> flatten_helper(node, [node | acc], current_ancestors ++ [node])
        _ -> [node | acc]
      end
    end)
  end
end

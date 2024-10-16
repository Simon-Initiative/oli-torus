defmodule Oli.Delivery.Hierarchy.HierarchyNode do
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
  @derive Jason.Encoder
  defstruct uuid: nil,
            numbering: nil,
            children: [],
            resource_id: nil,
            project_id: nil,
            project_slug: nil,
            section_resource: nil,
            revision: nil,
            ancestors: [],
            finalized: true,
            visited: false

  def simplify(%Oli.Delivery.Hierarchy.HierarchyNode{} = node) do
    %{
      id: node.resource_id,
      name: node.revision.title,
      children: Enum.map(node.children, &simplify/1)
    }
  end
end

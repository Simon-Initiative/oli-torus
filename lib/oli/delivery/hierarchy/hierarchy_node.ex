defmodule Oli.Delivery.Hierarchy.HierarchyNode do
  @moduledoc """
  HierarchyNode is a generic in-memory representation of a node within a hierarchy. This struct
  is shared across authoring and delivery and allows generalized components to work in both.

  A hierarchy is a single root node which contains children. The children in a node are intended
  to be fully instantiated structs (as opposed to just identifiers. However during the process of
  instantiating the hierarchy, children may temporarily be set as an identifier until the full
  hierarchy is instantiated).

  Notice that the hierarchy node also has a "slug" value. This value is used to uniquely identify
  the node within a set of nodes and therefore can be set to the revision's slug or section_resource's
  slug depending on which is more applicable. For example, a section's hierarchy could theoretically
  contain multiple nodes that have the same revision, and therefore using the section resource slug
  is more appropriate in the delivery context. However, since section resources do not exist in the
  authoring context, using the revision slug will be more appropriate. The actual values used are not
  necessarily important other than to uniquely identify the node in the hierarchy.
  """

  defstruct slug: nil,
            numbering: nil,
            children: [],
            resource_id: nil,
            project_id: nil,
            revision: nil,
            section_resource: nil
end

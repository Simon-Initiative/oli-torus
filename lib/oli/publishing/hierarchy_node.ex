defmodule Oli.Publishing.HierarchyNode do
  alias Oli.Publishing.HierarchyNode

  defstruct numbering_index: nil,
            numbering_level: nil,
            children: [],
            revision: nil,
            section_resource: nil

  @doc """
  From a constructed hierarchy root node, or a collection of hierarchy nodes, return
  a flat list of the revisions of only the pages in the hierarchy.
  """
  def flatten_pages(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], &flatten_pages(&1, &2))
  end

  def flatten_pages(%HierarchyNode{} = node), do: flatten_pages(node, [])

  defp flatten_pages(%HierarchyNode{} = node, all) do
    if node.revision.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") do
      [node.revision | all]
    else
      Enum.reduce(node.children, all, &flatten_pages(&1, &2))
    end
  end
end

defmodule Oli.Utils.HierarchyNode do
  defstruct revision: nil,
            children: [],
            numbering: nil

  @doc """
  From a constructed hierarchy root node, or a collection of hierarchy nodes, return
  a flat list of the revisions of only the pages in the hierarchy.
  """
  def flatten_pages(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], &flatten_pages(&1, &2))
  end

  def flatten_pages(%Oli.Utils.HierarchyNode{} = node), do: flatten_pages(node, [])

  defp flatten_pages(%Oli.Utils.HierarchyNode{} = node, all) do
    if node.revision.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") do
      [node.revision | all]
    else
      Enum.reduce(node.children, all, &flatten_pages(&1, &2))
    end
  end

end

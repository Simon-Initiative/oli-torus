defmodule Oli.Publishing.HierarchyNode do
  alias Oli.Publishing.HierarchyNode

  defstruct numbering: nil,
            children: [],
            resource_id: nil,
            revision: nil,
            section_resource: nil

  @doc """
  From a constructed hierarchy root node, or a collection of hierarchy nodes, return
  an ordered flat list of the nodes of only the pages in the hierarchy.
  """
  def flatten_pages(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], &flatten_pages(&1, &2))
  end

  def flatten_pages(%HierarchyNode{} = node), do: flatten_pages(node, []) |> Enum.reverse()

  defp flatten_pages(%HierarchyNode{} = node, all) do
    if node.revision.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") do
      [node | all]
    else
      Enum.reduce(node.children, all, &flatten_pages(&1, &2))
    end
  end

  # TODO: REMOVE
  # def flatten_hierarchy([], _), do: []

  # def flatten_hierarchy([h | t], revisions_by_resource_id) do
  #   revision = revisions_by_resource_id[h.resource_id]

  #   if ResourceType.get_type_by_id(revision.resource_type_id) == "container" do
  #     []
  #   else
  #     [h]
  #   end ++
  #     flatten_hierarchy(h.children, revisions_by_resource_id) ++
  #     flatten_hierarchy(t, revisions_by_resource_id)
  # end
end

defmodule Oli.Scenarios.Directives.CertificateSupport do
  @moduledoc false

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.Engine

  def resolve_target(state, target_name) do
    cond do
      section = Engine.get_section(state, target_name) ->
        {:ok, :section, section}

      product = Engine.get_product(state, target_name) ->
        {:ok, :product, product}

      true ->
        {:error, "Section or product '#{target_name}' not found"}
    end
  end

  def find_resource_id_by_title(section, title) do
    with {:ok, node} <- find_node_by_title(section, title),
         %{} = revision <- node.revision do
      {:ok, revision.resource_id}
    else
      nil -> {:error, "Page '#{title}' not found in section '#{section.slug}'"}
      {:error, _} = error -> error
    end
  end

  def resource_titles_for_ids(section, resource_ids) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    resource_ids
    |> Enum.map(fn resource_id -> find_title_by_resource_id(hierarchy, resource_id) end)
    |> Enum.reject(&is_nil/1)
  end

  def find_node_by_title(section, title) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    case do_find_node_by_title(hierarchy, title) do
      nil -> {:error, "Resource '#{title}' not found in section '#{section.slug}'"}
      node -> {:ok, node}
    end
  end

  defp do_find_node_by_title(%HierarchyNode{} = node, title) do
    cond do
      node.revision && node.revision.title == title ->
        node

      node.section_resource && node.section_resource.title == title ->
        node

      true ->
        Enum.find_value(node.children || [], fn child ->
          do_find_node_by_title(child, title)
        end)
    end
  end

  defp do_find_node_by_title(_, _title), do: nil

  defp find_title_by_resource_id(%HierarchyNode{} = node, resource_id) do
    cond do
      node.revision && node.revision.resource_id == resource_id ->
        node.revision.title

      true ->
        Enum.find_value(node.children || [], fn child ->
          find_title_by_resource_id(child, resource_id)
        end)
    end
  end

  defp find_title_by_resource_id(_, _resource_id), do: nil
end

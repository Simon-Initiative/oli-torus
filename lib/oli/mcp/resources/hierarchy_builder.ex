defmodule Oli.MCP.Resources.HierarchyBuilder do
  @moduledoc """
  Transforms AuthoringResolver.full_hierarchy/1 output into MCP resource format.
  
  Converts the HierarchyNode structure into a simplified format suitable for MCP clients,
  while maintaining the nested structure and including resource URIs.
  """

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.MCP.Resources.URIBuilder

  @doc """
  Converts a HierarchyNode into MCP resource format.
  
  Returns a simplified structure with:
  - resource_uri: MCP URI for the resource
  - resource_id: Torus resource ID
  - title: Human-readable title
  - resource_type: Type of resource (container, page, activity)
  - children: Nested children in the same format
  """
  def build_hierarchy_resource(%HierarchyNode{} = node, project_slug) do
    %{
      resource_uri: build_uri_for_resource(project_slug, node),
      resource_id: node.resource_id,
      title: get_title(node),
      resource_type: get_resource_type(node),
      children: Enum.map(node.children, &build_hierarchy_resource(&1, project_slug))
    }
  end

  defp build_uri_for_resource(project_slug, %HierarchyNode{revision: %{resource_type_id: resource_type_id}} = node) do
    case resource_type_id do
      1 -> URIBuilder.build_page_uri(project_slug, node.resource_id)       # Page
      2 -> URIBuilder.build_container_uri(project_slug, node.resource_id)  # Container
      _ -> URIBuilder.build_activity_uri(project_slug, node.resource_id)   # Activity
    end
  end

  defp get_title(%HierarchyNode{revision: %{title: title}}) when is_binary(title) and title != "", do: title
  defp get_title(%HierarchyNode{revision: %{slug: slug}}) when is_binary(slug) and slug != "", do: slug
  defp get_title(_), do: "Untitled"

  defp get_resource_type(%HierarchyNode{revision: %{resource_type_id: resource_type_id}}) do
    case resource_type_id do
      1 -> "page"
      2 -> "container"
      _ -> "activity"
    end
  end
end
defmodule OliWeb.Components.Delivery.CourseOutline do
  use Phoenix.Component

  import Phoenix.HTML.Link

  import OliWeb.PageDeliveryView, only: [container?: 1, container_title: 2]

  alias Oli.Resources.Numbering
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def outline(assigns) do
    ~H"""
    <%= for node <- @nodes do %>
      <li>
        <%= cond do %>
          <% container?(node) -> %>
            <.link_container {link_props(assigns, node)} />
          <% graded?(node) -> %>
            <.link_assessment {link_props(assigns, node)} />
          <% true -> %>
            <.link_page {link_props(assigns, node)} />
        <% end %>
      </li>
    <% end %>
    """
  end

  def link_container(assigns) do
    ~H"""
    <div class="border-b mb-2" style="border-color: #dee2e6;">
      <h5 class="text-delivery-primary border-delivery-primary mb-2">
        <%= link to: @container_link_url.(from_node(@node, :slug)),
            class: resource_link_class(@active_page == from_node(@node, :slug)) do %>
          <span class="container-title my-2">
            {container_title(@node, @display_curriculum_item_numbering)}
          </span>
        <% end %>
      </h5>
    </div>

    <%= if Enum.empty?(node_children(@node)) do %>
      <div class="text-secondary">There are no items</div>
    <% else %>
      <ol style="list-style: none; padding-left: 24px;">
        <.outline {Map.merge(assigns, %{
            nodes: node_children(@node),
            active_page: nil,
          })} />
      </ol>
    <% end %>
    """
  end

  def link_shallow_container(assigns) do
    ~H"""
    <div class="border-b mb-2" style="border-color: #dee2e6;">
      <%= link to: @container_link_url.(from_node(@node, :slug)),
          class: resource_link_class(@active_page == from_node(@node, :slug)) do %>
        <span class="container-title my-2">
          {container_title(@node, @display_curriculum_item_numbering)}
        </span>
      <% end %>
    </div>
    """
  end

  def link_assessment(assigns) do
    ~H"""
    <div class="d-flex border-b mb-2" style="border-color: #dee2e6;">
      <div class="flex-grow-1">
        <%= link to: @page_link_url.(from_node(@node, :slug)),
            class: resource_link_class(@active_page == from_node(@node, :slug)) do %>
          <span class="page-title">
            <i class="fa fa-file-pen mr-2"></i> {from_node(@node, :title)}
          </span>
        <% end %>
      </div>
      <div class="mr-2">
        {node_index(@node)}
      </div>
    </div>
    """
  end

  def link_page(assigns) do
    ~H"""
    <div class="d-flex border-b mb-2" style="border-color: #dee2e6;">
      <div class="flex-grow-1">
        <%= link to: @page_link_url.(from_node(@node, :slug)),
            class: resource_link_class(@active_page == from_node(@node, :slug)) do %>
          <span class="page-title">
            <i class="far fa-file mr-2"></i> {from_node(@node, :title)}
          </span>
        <% end %>
      </div>
      <div class="mr-2">
        {node_index(@node)}
      </div>
    </div>
    """
  end

  defp link_props(assigns, node) do
    Map.merge(assigns, %{
      node: node,
      nodes: node_children(node)
    })
  end

  defp base_resource_link_class(), do: "text-delivery-primary hover:text-delivery-primary"
  defp resource_link_class(_active = true), do: base_resource_link_class() <> " active"
  defp resource_link_class(_active = false), do: base_resource_link_class()

  defp from_node(%HierarchyNode{revision: revision}, field), do: Map.get(revision, field)
  defp from_node(map, field), do: Map.get(map, Atom.to_string(field))

  defp graded?(node) do
    from_node(node, :graded) == "true"
  end

  defp node_index(%HierarchyNode{numbering: %Numbering{index: index}}), do: index
  defp node_index(%{"index" => index}), do: index

  defp node_children(%HierarchyNode{children: children}), do: children
  defp node_children(%{"children" => children}), do: children
end

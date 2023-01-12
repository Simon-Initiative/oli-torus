defmodule OliWeb.Delivery.Remix.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  import OliWeb.Curriculum.Utils, only: [is_container?: 1]

  use Phoenix.Component

  alias OliWeb.Delivery.Remix.Actions
  alias Oli.Delivery.Hierarchy.HierarchyNode

  def entry(%{node: %HierarchyNode{}} = assigns) do
    ~H"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id={"entry-#{@node.resource_id}"}
      draggable="true"
      phx-click="select"
      phx-value-uuid={@node.uuid}
      phx-value-index={@index}
      data-drag-index={@index}
      data-drag-uuid={@node.uuid}
      phx-hook="DragSource"
      class={"p-2 flex-grow-1 d-flex curriculum-entry" <> if @selected do " active" else "" end}>

      <div class="flex-grow-1 d-flex flex-column self-center">
        <div class="flex-1">
          <%= icon(assigns) %>
          <%= if is_container?(@node.revision) do %>
            <button class="btn btn-link ml-1 mr-1 entry-title" phx-click="set_active" phx-value-uuid={@node.uuid}><%= @node.revision.title %></button>
          <% else %>
            <span class="ml-1 mr-1 entry-title"><%= @node.revision.title %></span>
          <% end %>
        </div>
      </div>

      <%# prevent dragging of actions menu and modals using this draggable wrapper %>
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <%= live_component Actions, uuid: @node.uuid %>
      </div>
    </div>
    """
  end

  def icon(%{node: %HierarchyNode{revision: revision}} = assigns) do
    if is_container?(revision) do
      ~H"""
      <i class="fas fa-archive font-bold fa-lg mx-2"></i>
      """
    else
      if revision.graded do
        ~H"""
        <i class="far fa-list-alt fa-lg mx-2"></i>
        """
      else
        ~H"""
        <i class="far fa-file-alt fa-lg mx-2"></i>
        """
      end
    end
  end
end

defmodule OliWeb.Delivery.Remix.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  import OliWeb.Curriculum.Utils, only: [is_container?: 1]

  use Phoenix.Component

  alias OliWeb.Delivery.Remix.Actions
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias OliWeb.Router.Helpers, as: Routes

  attr :node, :map, required: true
  attr :index, :integer, required: true
  attr :selected, :boolean, required: true
  attr :is_product, :boolean, default: false

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
      class={"p-2 flex-grow-1 d-flex curriculum-entry" <> if @selected do " active" else "" end}
    >
      <div class="flex-grow-1 d-flex flex-column self-center">
        <div class="flex-1">
          {icon(assigns)}
          <%= if is_container?(@node.revision) do %>
            <button
              class="btn btn-link ml-1 mr-1 entry-title"
              phx-click="set_active"
              phx-value-uuid={@node.uuid}
            >
              {@node.revision.title}
            </button>
          <% else %>
            <span class="ml-1 mr-1 entry-title">{@node.revision.title}</span>
            <%= if @is_product and !is_nil(@node.project_slug) do %>
              <a
                id={"product-page-#{@node.revision.slug}"}
                class="entry-title mx-3"
                href={
                  Routes.resource_path(
                    OliWeb.Endpoint,
                    :edit,
                    @node.project_slug,
                    @node.revision.slug
                  )
                }
              >
                Edit Page
              </a>
            <% end %>
          <% end %>
        </div>
      </div>

      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <.live_component
          module={Actions}
          uuid={@node.uuid}
          hidden={(@node.section_resource && @node.section_resource.hidden) || false}
          resource_type={@node.revision.resource_type_id}
          id={"remix_actions_#{@node.uuid}"}
        />
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

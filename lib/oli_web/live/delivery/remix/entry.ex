defmodule OliWeb.Delivery.Remix.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  import OliWeb.Curriculum.Utils, only: [is_container?: 1]

  use Phoenix.Component

  def entry(%{index: index, revision: revision, selected: selected} = assigns) do
    ~H"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id={revision.resource_id}
      draggable="true"
      phx-click="select"
      phx-value-slug={revision.slug}
      phx-value-index={index}
      data-drag-index={index}
      data-drag-slug={revision.slug}
      phx-hook="DragSource"
      class={"p-2 flex-grow-1 d-flex curriculum-entry" <> if selected do " active" else "" end}>

      <div class="flex-grow-1 d-flex flex-column align-self-center">
        <div class="flex-1">
          <%= icon(assigns) %>
          <button class="btn btn-link ml-1 mr-1 entry-title" phx-click="set_active" phx-value-slug={revision.slug} disabled={!is_container?(revision)}><%= revision.title %></button>
        </div>
      </div>

      <%# prevent dragging of actions menu and modals using this draggable wrapper %>
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <%= # live_component Actions, assigns %>
      </div>
    </div>
    """
  end

  def icon(%{revision: revision} = assigns) do
    if is_container?(revision) do
      ~H"""
      <i class="las la-archive font-bold fa-lg mx-2"></i>
      """
    else
      if revision.graded do
        ~H"""
        <i class="lar la-list-alt fa-lg mx-2"></i>
        """
      else
        ~L"""
        <i class="lar la-file-alt fa-lg mx-2"></i>
        """
      end
    end
  end
end

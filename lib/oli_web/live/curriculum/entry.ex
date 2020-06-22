defmodule OliWeb.Curriculum.Entry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do

    active = if assigns.selected do "background-color: #eee;" else "" end
    type = if assigns.page.graded do "Assessment" else "Page" end
    muted = if assigns.selected do "" else "text-muted" end

    ~L"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id="<%= @page.resource_id %>"
      draggable="true"
      style="cursor: pointer; border-radius: 3px; <%= active %>"
      phx-click="select"
      phx-value-slug="<%= @page.slug %>"
      phx-value-index="<%= assigns.index %>"
      data-drag-index="<%= assigns.index %>"
      phx-hook="DragSource"
      class="p-1 d-flex justify-content-start curriculum-entry">

      <div class="drag-handle">
        <div class="grip"></div>
      </div>

      <div class="m-2 text-truncate" style="width: 100%;">
        <div class="d-flex justify-content-between align-items-center">
          <a
            style="margin: 2px"
            onClick="event.stopPropagation();"
            href="<%= Routes.resource_path(OliWeb.Endpoint, :edit, @project.slug, @page.slug) %>"><%= @index + 1 %>. <%= @page.title %>
          </a>
          <small class="<%= muted %>"><%= type %></small>
        </div>
      </div>

    </div>
    """
  end
end

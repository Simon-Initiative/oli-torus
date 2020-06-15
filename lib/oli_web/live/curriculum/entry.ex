defmodule OliWeb.Curriculum.Entry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do

    active = if assigns.selected do "background-color: #dddddd;" else "" end
    type = if assigns.page.graded do "Assessment" else "Page" end
    muted = if assigns.selected do "" else "text-muted" end

    ~L"""
    <div
      id="<%= @page.resource_id %>"
      draggable="true"
      style="cursor: pointer; <%= active %>"
      phx-click="select"
      phx-value-slug="<%= @page.slug %>"
      phx-hook="DragSource"
      data-drag-index="<%= assigns.index %>"
      class="p-1 d-flex justify-content-start curriculum-entry">

      <div class="drag-handle">
        <div class="grip"></div>
      </div>

      <div class="m-2 text-truncate" style="width: 100%;">
        <div class="d-flex justify-content-between">
          <a
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

defmodule OliWeb.Curriculum.Entry do
  use Phoenix.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do

    active = if assigns.selected do "active" else "" end
    type = if assigns.page.graded do "Assessment" else "Page" end
    link_style = if assigns.selected do "color: white" else "" end
    muted = if assigns.selected do "" else "text-muted" end

    ~L"""
    <div
      style="cursor: pointer;"
      phx-click="select"
      phx-value-slug="<%= @page.slug %>"
      class="list-group-item list-group-item-action d-flex justify-content-start <%= active %> ">

      <div class="dragHandleGrab">
        <div class="grip<%=active%>"></div>
      </div>

      <div class="m-2 text-truncate" style="width: 100%;">
        <div class="d-flex justify-content-between">
          <a
            style="<%=link_style%>"
            onClick="event.stopPropagation();"
            href="<%= Routes.resource_path(OliWeb.Endpoint, :edit, @project.slug, @page.slug) %>"><%= @index + 1 %>. <%= @page.title %>
          </a>
          <small class="<%= muted %>"><%= type %></small>
        </div>

        <small class="<%= muted %>">You are currently editing this page</small>
      </div>

    </div>
    """
  end
end

defmodule OliWeb.Curriculum.SimpleEntry do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Curriculum.Entry
  import OliWeb.Projects.Table, only: [time_ago: 2]
  alias OliWeb.Common.AuthorInitials

  def render(assigns) do
    ~L"""
      <div class="d-flex flex-column w-100">
        <div class="d-flex justify-content-between">
          <div class="d-flex">
            <span class="mr-2"><%= Entry.icon(@child) %></span>
            <a
              class="entry-title"
              onClick="event.stopPropagation();"
              href="<%= Routes.resource_path(OliWeb.Endpoint, :edit, @project.slug, @child.slug) %>">
              <%= @child.title %>
            </a>
          </div>
          <div>
            Options
          </div>
        </div>
        <%= if @editor do %>
          <div class="mt-1 mb-1 d-inline-flex align-items-center">
            <span class="d-inline-flex mr-1">Being edited by</span>
            <%= live_component @socket, AuthorInitials, author: @editor, size: 24 %>
          </div>
        <% end %>
        <div class="d-flex flex-column">
          <small>Created <%= time_ago(assigns, @child.resource.inserted_at) %></small>
          <small>Updated <%= time_ago(assigns, @child.inserted_at) %> by <%= @child.author.first_name %></small>
        </div>
      </div>
    """
  end
end

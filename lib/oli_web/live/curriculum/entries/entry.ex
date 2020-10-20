defmodule OliWeb.Curriculum.EntryLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias OliWeb.Curriculum.LearningSummaryEntryLive
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links
  import OliWeb.Projects.Table, only: [time_ago: 2]

  def render(assigns) do
    ~L"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id="<%= @child.resource_id %>"
      draggable="true"
      phx-click="select"
      phx-value-slug="<%= @child.slug %>"
      phx-value-index="<%= assigns.index %>"
      data-drag-index="<%= assigns.index %>"
      phx-hook="DragSource"
      class="p-2 flex-1 d-flex justify-content-start curriculum-entry<%= if @selected do " active" else "" end %>">

      <div class="text-truncate" style="width: 100%;">
        <div class="d-flex align-items-top">
          <div class="d-flex flex-column w-100">
            <div class="d-flex justify-content-between">
              <div class="curriculum-title-line d-flex align-items-center">
                <%= icon(assigns) %>
                <%= Links.resource_link(@child, [], @project, "ml-1 mr-1 entry-title") %>
                <%= if @editor do %>
                  <span class="badge">
                    <%= @editor.first_name %> is editing this
                  </span>
                <% end %>
              </div>
              <%= live_patch to: Routes.container_path(@socket, :edit, @project.slug, @container.slug, @child.slug),
                class: "button" do %>
                <button
                class="list-unstyled"
                style="border:none; background: none; color: #212529">
                  <i class="material-icons">more_vert</i>
                </button>
              <% end %>
            </div>
            <div class="container">
              <div class="row">
                <div class="entry-section d-flex flex-column <%= if @view == "Simple" do "col-12" else "col-4" end %>">
                  <small class="text-muted">Created <%= time_ago(assigns, @child.resource.inserted_at) %></small>
                  <small class="text-muted">Updated <%= time_ago(assigns, @child.inserted_at) %> <%= if @view == "Simple" do "by #{@child.author.first_name}" else "" end %></small>
                </div>
                <%= if @view == "Learning Summary" && !is_container?(@child) do %>
                  <%= live_component @socket, LearningSummaryEntryLive, assigns %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def is_container?(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id) == "container"
  end

  def icon(%{child: child} = assigns) do
    ~L"""
    <i class="material-icons-outlined">
      <%= if is_container?(child) do "folder" else if child.graded do "check_box" else "assignment" end end %>
    </i>
    """
  end
end

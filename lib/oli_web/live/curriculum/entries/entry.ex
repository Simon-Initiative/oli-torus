defmodule OliWeb.Curriculum.EntryLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias OliWeb.Curriculum.{DetailsLive, LearningSummaryLive}
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links

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
                <%= Links.resource_link(@child, [], @project, @numberings, "ml-1 mr-1 entry-title") %>
                <%= if is_container?(@child) do %>
                  <%= live_patch to: Routes.container_path(@socket, :edit, @project.slug, @container.slug, @child.slug),
                  class: "button" do %>
                    <button
                    class="list-unstyled"
                    style="border:none; background: none; color: #212529">
                      <i class="material-icons">arrow_drop_down</i>
                    </button>
                  <% end %>
                <% end %>
                <%= if @editor do %>
                  <span class="badge">
                    <%= Map.get(@editor, :name) || "A user" %> is editing this
                  </span>
                <% end %>
              </div>
              <%= if !is_container?(@child) do %>
                <%= live_patch to: Routes.container_path(@socket, :edit, @project.slug, @container.slug, @child.slug),
                  class: "button" do %>
                  <button
                  class="list-unstyled"
                  style="border:none; background: none; color: #212529">
                    <i class="material-icons">more_vert</i>
                  </button>
                <% end %>
              <% end %>
            </div>
            <div class="container">
              <div class="row">
                <%= case @view do
                  "Details" ->
                    live_component @socket, DetailsLive, assigns
                  "Learning Summary" ->
                    live_component @socket, LearningSummaryLive, assigns
                  _ ->
                    nil
                end %>
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

defmodule OliWeb.Curriculum.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias OliWeb.Curriculum.{LearningSummaryEntry}
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Curriculum.Settings
  alias OliWeb.Common.ManualModal
  import OliWeb.Projects.Table, only: [time_ago: 2]
  alias Oli.Resources.Numbering

  def mount(socket) do
    {:ok,
     assign(socket,
       modal_shown: false
     )}
  end

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
                <%= icon(@child) %>
                <a
                  class="ml-1 mr-1 entry-title"
                  onClick="event.stopPropagation();"
                  href="<%= resource_link(assigns, @child.resource_type_id) %>">
                  <%= title(@numbering, @child) %>
                </a>
                <%= if @editor do %>
                  <span class="badge">
                    <%= @editor.first_name %> is editing this
                  </span>
                <% end %>
              </div>
              <a
                href="#"
                phx-click="toggle_settings"
                phx-target="<%= @myself %>"
                onClick="event.preventDefault();"
                class="list-unstyled"
                style="color: #212529">
                <i class="material-icons">more_vert</i>
              </a>
            </div>
            <div class="container">
              <div class="row">
                <div class="entry-section d-flex flex-column <%= if @view == "Simple" do "col-12" else "col-4" end %>">
                  <small class="text-muted">Created <%= time_ago(assigns, @child.resource.inserted_at) %></small>
                  <small class="text-muted">Updated <%= time_ago(assigns, @child.inserted_at) %> <%= if @view == "Simple" do "by #{@child.author.first_name}" else "" end %></small>
                </div>
                <%= if @view == "Learning Summary" && !is_container?(@child.resource_type_id) do %>
                  <%= live_component @socket, LearningSummaryEntry, assigns %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%= if @modal_shown do %>
      <%= live_component @socket, ManualModal, title: "#{@child.title} settings", modal_id: "entry-settings", ok_action: "save", ok_label: "Save" do %>
        <%= live_component @socket, Settings, child: @child, changeset: @changeset, project: @project %>
      <% end %>
    <% end %>
    """
  end

  defp is_container?(resource_type_id) do
    case ResourceType.get_type_by_id(resource_type_id) do
      "container" -> true
      _ -> false
    end
  end

  defp resource_link(assigns, resource_type_id) do
    if is_container?(resource_type_id) do
      Routes.live_path(
        assigns.socket,
        OliWeb.Curriculum.Container,
        assigns.project.slug,
        assigns.child.slug
      )
    else
      Routes.resource_path(OliWeb.Endpoint, :edit, assigns.project.slug, assigns.child.slug)
    end
  end

  defp title(numbering, rev) do
    if is_container?(rev.resource_type_id) do
      Numbering.prefix(Map.get(numbering, rev.id)) <> ": " <> rev.title
    else
      rev.title
    end
  end

  def icon(rev) do
    ~s|<i class="material-icons-outlined">#{
      if is_container?(rev.resource_type_id) do
        "folder"
      else
        if rev.graded do
          "check_box"
        else
          "assignment"
        end
      end
    }</i>|
    |> raw()
  end

  def handle_event("toggle_settings", _params, socket) do
    {:noreply, assign(socket, modal_shown: true)}
  end
end

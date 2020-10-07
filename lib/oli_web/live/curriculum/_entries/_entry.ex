defmodule OliWeb.Curriculum.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias OliWeb.Curriculum.{DetailsEntry}
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Curriculum.Settings
  alias OliWeb.Common.EmptyModal
  import OliWeb.Projects.Table, only: [time_ago: 2]
  alias OliWeb.Common.AuthorInitials

  def mount(socket) do
    {:ok, assign(socket,
      modal_shown: false
    )}
  end

  def render(assigns) do
    active_class =
      if assigns.selected do
        " active"
      else
        ""
      end

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
      class="p-2 flex-1 d-flex justify-content-start curriculum-entry<%= active_class %>">

      <div class="text-truncate" style="width: 100%;">
        <div class="d-flex align-items-top">
          <%= case @active_view do %>
            <% "Simple" -> %>
              <div class="d-flex flex-column w-100">
                <div class="d-flex justify-content-between">
                  <div class="curriculum-title-line d-flex align-items-center">
                    <%= icon(@child) %>
                    <a
                      class="ml-1 mr-1 entry-title"
                      onClick="event.stopPropagation();"
                      href="<%= resource_link(assigns, @child.resource_type_id) %>">
                      <%= @child.title %>
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
                    class="entry-settings list-unstyled">
                    <i class="material-icons">more_vert</i>
                    <%= if @modal_shown do %>
                      <div class="entry-options">
                        <%= live_component @socket, EmptyModal, modal_id: "entry-settings" do %>
                          <%= live_component @socket, Settings, child: @child, changeset: @changeset, project: @project %>
                        <% end %>
                      </div>
                    <% end %>
                  </a>
                </div>
                <div class="d-flex flex-column">
                  <small>Created <%= time_ago(assigns, @child.resource.inserted_at) %></small>
                  <small>Updated <%= time_ago(assigns, @child.inserted_at) %> by <%= @child.author.first_name %></small>
                </div>
              </div>
            <% "Details" -> %><%= live_component @socket, DetailsEntry, assigns %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def resource_link(assigns, resource_type_id) do
    case ResourceType.get_type_by_id(resource_type_id) do
      "page" -> Routes.resource_path(OliWeb.Endpoint, :edit, assigns.project.slug, assigns.child.slug)
      "container" -> Routes.live_path(assigns.socket, OliWeb.Curriculum.Container, assigns.project.slug, assigns.child.slug)
      _ -> "#"
    end
  end

  def icon(rev) do
    ~s|<i class="material-icons-outlined">#{
      case ResourceType.get_type_by_id(rev.resource_type_id) do
        "container" ->
          "folder"

        "page" ->
          case rev.graded do
            true -> "check_box"
            false -> "assignment"
          end
      end
    }</i>|
    |> raw()
  end

  def handle_event("toggle_settings", _params, socket) do
    IO.inspect(!socket.assigns.modal_shown)
    {:noreply, assign(socket, modal_shown: !socket.assigns.modal_shown)}
  end
end

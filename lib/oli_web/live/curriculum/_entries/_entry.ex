defmodule OliWeb.Curriculum.Entry do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  alias OliWeb.Curriculum.{SimpleEntry, DetailsEntry}
  alias Oli.Resources.ResourceType

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
            <% "Simple" -> %><%= live_component @socket, SimpleEntry, assigns %>
            <% "Details" -> %><%= live_component @socket, DetailsEntry, assigns %>
          <% end %>
        </div>
      </div>
    </div>
    """
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
end

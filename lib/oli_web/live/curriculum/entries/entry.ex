defmodule OliWeb.Curriculum.EntryLive do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.{Actions, DetailsLive, LearningSummaryLive}
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
      data-drag-slug="<%= @child.slug %>"
      phx-hook="DragSource"
      class="p-2 flex-grow-1 d-flex curriculum-entry <%= if @selected do "active" else "" end %>">

      <div class="flex-grow-1 d-flex flex-column align-self-center">
        <div class="flex-1">
          <%= icon(assigns) %>
          <%= Links.resource_link(@child, [], @project, @numberings, "ml-1 mr-1 entry-title") %>
          <%= if @editor do %>
            <span class="badge">
              <%= Map.get(@editor, :name) || "Someone" %> is editing this
            </span>
          <% end %>
        </div>
        <div>
          <%= case @view do
            "Detailed" ->
              live_component DetailsLive, assigns
            "Learning Summary" ->
              live_component LearningSummaryLive, assigns
            _ ->
              nil
          end %>
        </div>
      </div>

      <%# prevent dragging of actions menu and modals using this draggable wrapper %>
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <%= live_component Actions, assigns %>
      </div>
    </div>
    """
  end

  def icon(%{child: child} = assigns) do
    ~L"""
    <i class="material-icons-outlined">
      <%= if is_container?(child) do "folder" else if child.graded do "check_box" else "description" end end %>
    </i>
    """

    if is_container?(child) do
      ~L"""
      <i class="las la-archive font-bold fa-lg mx-2"></i>
      """
    else
      if child.graded do
        ~L"""
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

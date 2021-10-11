defmodule OliWeb.Objectives.Actions do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
      <div class="objective-actions p-2">

        <%= if !@has_children and @depth < 2 do %>
          <button
            class="ml-1 btn btn-sm btn-light"
            phx-click="show_breakdown_modal"
            phx-value-slug="<%= @slug %>">
            <i class="las la-sitemap"></i> Break down
          </button>
        <% end %>

        <button
          class="ml-1 btn btn-sm btn-light"
          phx-click="modify"
          phx-value-slug="<%= @slug %>">
        <i class="las la-i-cursor"></i> Reword
        </button>

        <button
          id="delete_<%= @slug %>"
<<<<<<< HEAD
          disabled
          <% # disable the ability to delete until #1616 is resolved %>
          <% # if @can_delete? do "" else "disabled" end %>
          phx-click="prepare_delete"
=======
          <%= if @can_delete? do "" else "disabled" end %>
          phx-click="show_delete_modal"
>>>>>>> master
          phx-value-slug="<%= @slug %>"
          data-backdrop="static"
          data-keyboard="false"
          class="ml-1 btn btn-sm btn-danger">
        <i class="fas fa-trash-alt fa-lg"></i> Remove
        </button>

      </div>
    """
  end
end

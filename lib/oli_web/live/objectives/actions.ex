defmodule OliWeb.Objectives.Actions do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
      <div class="objective-actions p-2">

        <button
          class="ml-1 btn btn-sm btn-light"
          phx-click="modify"
          phx-value-parent_slug="<%= @parent_slug_value %>"
          phx-value-slug="<%= @slug %>">
        <i class="las la-i-cursor"></i> Reword
        </button>

        <button
          id="delete_<%= @slug %>"
          <%= if @can_delete? do "" else "disabled" end %>
          phx-click="show_delete_modal"
          phx-value-slug="<%= @slug %>"
          phx-value-parent_slug="<%= @parent_slug_value %>"
          data-backdrop="static"
          data-keyboard="false"
          class="ml-1 btn btn-sm btn-danger">
        <i class="fas fa-trash-alt fa-lg"></i> Remove
        </button>

      </div>
    """
  end
end

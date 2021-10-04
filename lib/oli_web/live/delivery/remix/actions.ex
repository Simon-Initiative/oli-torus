defmodule OliWeb.Delivery.Remix.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  def render(assigns) do
    ~L"""
    <div class="entry-actions">
      <button type="button" class="btn btn-outline-primary btn-sm ml-2" phx-click="show_move_modal" phx-value-slug="<%= @slug %>">
        <i class="las la-arrow-circle-right"></i> Move
      </button>
      <button type="button" class="btn btn-danger btn-sm ml-2" phx-click="show_remove_modal" phx-value-slug="<%= @slug %>">
        <i class="lar la-trash-alt"></i> Remove
      </button>
    </div>
    """
  end
end

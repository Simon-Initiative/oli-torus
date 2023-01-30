defmodule OliWeb.Delivery.Remix.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="entry-actions">
      <button type="button" class="btn btn-outline-primary btn-sm ml-2" phx-click="show_move_modal" phx-value-uuid={@uuid}>
        <i class="fas fa-arrow-circle-right"></i> Move
      </button>
      <button type="button" class="btn btn-danger btn-sm ml-2" phx-click="show_remove_modal" phx-value-uuid={@uuid}>
        <i class="far fa-trash-alt"></i> Remove
      </button>
    </div>
    """
  end
end

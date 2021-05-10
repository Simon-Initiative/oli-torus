defmodule OliWeb.Curriculum.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  def render(assigns) do
    ~L"""
    <div class="entry-actions">
      <div class="dropdown">
        <button class="btn dropdown-toggle" type="button" id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"></button>
        <div class="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
          <button type="button" class="dropdown-item" phx-click="show_details_modal" phx-value-slug="<%= @child.slug %>"><i class="las la-sliders-h mr-1"></i> Details</button>
          <button type="button" class="dropdown-item" phx-click="show_move_modal" phx-value-slug="<%= @child.slug %>"><i class="las la-arrow-circle-right mr-1"></i> Move to...</button>
          <div class="dropdown-divider"></div>
          <button type="button" class="dropdown-item text-danger" phx-click="show_delete_modal" phx-value-slug="<%= @child.slug %>"><i class="lar la-trash-alt mr-1"></i> Delete</button>
        </div>
      </div>
    </div>
    """
  end

end

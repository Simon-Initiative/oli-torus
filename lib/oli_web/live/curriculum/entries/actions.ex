defmodule OliWeb.Curriculum.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  alias Oli.Resources.ResourceType

  def render(assigns) do
    ~H"""
    <div class="entry-actions">
      <div class="dropdown">
        <button class="btn dropdown-toggle" type="button" data-bs-toggle="dropdown" data-target={"dropdownMenu_#{@child.slug}"} aria-haspopup="true" aria-expanded="false">
          <svg
            aria-hidden="true"
            focusable="false"
            data-prefix="fas"
            data-icon="caret-down"
            class="w-2 ml-2"
            role="img"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 320 512"
          >
            <path
              fill="currentColor"
              d="M31.3 192h257.3c17.8 0 26.7 21.5 14.1 34.1L174.1 354.8c-7.8 7.8-20.5 7.8-28.3 0L17.2 226.1C4.6 213.5 13.5 192 31.3 192z"
            ></path>
          </svg>
        </button>
        <div class="dropdown-menu dropdown-menu-right" id={"dropdownMenu_#{@child.slug}"} aria-labelledby={"dropdownMenuButton_#{@child.slug}"}>
          <button type="button" class="dropdown-item" phx-click="show_options_modal" phx-value-slug={@child.slug}><i class="fas fa-sliders-h mr-1 flex-1"></i> Options</button>
          <button type="button" class="dropdown-item" phx-click="show_move_modal" phx-value-slug={@child.slug}><i class="fas fa-arrow-circle-right mr-1"></i> Move to...</button>
          <%= if ResourceType.is_non_adaptive_page(@child) do %>
            <button type="button" class="dropdown-item" phx-click="duplicate_page" phx-value-id={@child.id}><i class="fas fa-copy mr-1"></i> Duplicate</button>
          <% end %>
          <div class="dropdown-divider"></div>
          <button type="button" class="dropdown-item text-danger" phx-click="show_delete_modal" phx-value-slug={@child.slug}><i class="far fa-trash-alt mr-1"></i> Delete</button>
        </div>
      </div>
    </div>
    """
  end
end

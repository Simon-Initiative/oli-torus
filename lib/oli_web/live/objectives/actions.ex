defmodule OliWeb.ObjectivesLive.Actions do
  use Phoenix.Component

  attr :slug, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="flex flex-row-reverse p-2">
      <button
        phx-click="display_new_sub_modal"
        phx-value-slug={@slug}
        class="ml-1 btn btn-sm btn-light"
      >
        <i class="fas fa-plus fa-lg"></i> Create new Sub-Objective
      </button>

      <button
        phx-click="display_add_existing_sub_modal"
        phx-value-slug={@slug}
        class="ml-1 btn btn-sm btn-light"
      >
        <i class="fas fa-plus fa-lg"></i> Add existing Sub-Objective
      </button>

      <button phx-click="display_edit_modal" phx-value-slug={@slug} class="ml-1 btn btn-sm btn-light">
        <i class="fas fa-i-cursor"></i> Reword
      </button>

      <button
        phx-click="display_delete_modal"
        phx-value-slug={@slug}
        class="ml-1 btn btn-sm btn-danger"
      >
        <i class="fas fa-trash-alt fa-lg"></i> Remove
      </button>
    </div>
    """
  end
end

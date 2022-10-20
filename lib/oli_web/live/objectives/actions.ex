defmodule OliWeb.ObjectivesLive.Actions do
  use Surface.Component

  prop slug, :string, required: true

  def render(assigns) do
    ~F"""
      <div class="float-right p-2">
        <button
          :on-click="display_new_sub_modal"
          :values={slug: @slug}
          class="ml-1 btn btn-sm btn-light">
          <i class="fas fa-plus fa-lg"></i> Create new Sub-Objective
        </button>

        <button
          :on-click="display_add_existing_sub_modal"
          :values={slug: @slug}
          class="ml-1 btn btn-sm btn-light">
          <i class="fas fa-plus fa-lg"></i> Add existing Sub-Objective
        </button>

        <button
          :on-click="display_edit_modal"
          :values={slug: @slug}
          class="ml-1 btn btn-sm btn-light">
          <i class="las la-i-cursor"></i> Reword
        </button>

        <button
          :on-click="display_delete_modal"
          :values={slug: @slug}
          class="ml-1 btn btn-sm btn-danger">
          <i class="fas fa-trash-alt fa-lg"></i> Remove
        </button>
      </div>
    """
  end
end

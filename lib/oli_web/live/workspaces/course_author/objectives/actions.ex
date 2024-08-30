defmodule OliWeb.Workspaces.CourseAuthor.Objectives.Actions do
  use Phoenix.Component

  import OliWeb.Components.Common

  attr :slug, :string, required: true

  def actions(assigns) do
    ~H"""
    <div class="flex flex-row-reverse p-2">
      <.button
        variant={:light}
        size={:sm}
        phx-click="display_new_sub_modal"
        phx-value-slug={@slug}
        class="ml-1"
      >
        <i class="fas fa-plus fa-lg"></i> Create new Sub-Objective
      </.button>

      <.button
        variant={:light}
        size={:sm}
        phx-click="display_add_existing_sub_modal"
        phx-value-slug={@slug}
        class="ml-1"
      >
        <i class="fas fa-plus fa-lg"></i> Add existing Sub-Objective
      </.button>

      <.button
        variant={:light}
        size={:sm}
        phx-click="display_edit_modal"
        phx-value-slug={@slug}
        class="ml-1"
      >
        <i class="fas fa-i-cursor"></i> Reword
      </.button>

      <.button
        variant={:danger}
        size={:sm}
        phx-click="display_delete_modal"
        phx-value-slug={@slug}
        class="ml-1"
      >
        <i class="fas fa-trash-alt fa-lg"></i> Remove
      </.button>
    </div>
    """
  end
end

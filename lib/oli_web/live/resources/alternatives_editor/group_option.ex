defmodule OliWeb.Resources.AlternativesEditor.GroupOption do
  use Phoenix.Component

  alias OliWeb.Components.ReorderableList
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  attr :group, :any, required: true
  attr :show_actions, :boolean, default: true
  attr :list_class, :string, default: "list-group"

  def option_list(assigns) do
    assigns = assign(assigns, :option_count, length(assigns.group.content["options"]))

    ~H"""
    <ReorderableList.status id={"alternatives-reorder-status-#{@group.resource_id}"} />
    <ul class={@list_class}>
      <%= for {option, position} <- Enum.with_index(@group.content["options"]) do %>
        <.option_drop_target :if={@show_actions} group={@group} position={position} />
        <.group_option
          group={@group}
          option={option}
          position={position}
          option_count={@option_count}
          show_actions={@show_actions}
        />
      <% end %>
      <.option_drop_target :if={@show_actions} group={@group} position={@option_count} />
    </ul>
    """
  end

  attr :group, :any, required: true
  attr :option, :map, required: true
  attr :show_actions, :boolean, default: true
  attr :position, :integer, default: 0
  attr :option_count, :integer, default: 1

  def group_option(assigns) do
    ~H"""
    <ReorderableList.item
      tag="li"
      id={"alternatives-option-#{@group.resource_id}-#{@option["id"]}"}
      position={@position}
      count={@option_count}
      item_key={"alternatives:#{@group.resource_id}:#{@option["id"]}"}
      label={@option["name"]}
      status_id={"alternatives-reorder-status-#{@group.resource_id}"}
      keydown="keyboard_reorder_option"
      enabled={@show_actions}
      class={[
        "list-group-item p-3 d-flex curriculum-entry",
        @show_actions && "cursor-grab active:cursor-grabbing"
      ]}
      phx-value-resource-id={@group.resource_id}
      phx-value-option-id={@option["id"]}
      data-reorder-item-id={@option["id"]}
      data-reorder-resource-id={@group.resource_id}
      data-reorder-scope={"alternatives-#{@group.resource_id}"}
      aria-label={@option["name"]}
    >
      <div class="d-flex flex-row align-items-center flex-grow-1">
        <i
          :if={@show_actions}
          class="fa-solid fa-grip-vertical mr-3 text-xs text-gray-300 dark:text-gray-600"
          aria-hidden="true"
        >
        </i>
        <div>{@option["name"]}</div>
        <div class="flex-grow-1"></div>
        <%= if @show_actions do %>
          <div
            id={"alternatives-option-actions-#{@group.resource_id}-#{@option["id"]}"}
            draggable="true"
            class="entry-actions dropdown"
            ondragstart="event.preventDefault(); event.stopPropagation();"
            phx-keydown={close_actions(@group.resource_id, @option["id"], true)}
            phx-key="Escape"
          >
            <button
              id={"dropdownMenuButton_#{@group.resource_id}_#{@option["id"]}"}
              class="btn dropdown-toggle"
              type="button"
              aria-label="Options"
              title="Options"
              aria-expanded="false"
              aria-controls={"dropdownMenu_#{@group.resource_id}_#{@option["id"]}"}
              phx-click={toggle_actions(@group.resource_id, @option["id"])}
            >
              <Icons.vertical_dots class="text-gray-700 dark:text-gray-100" />
            </button>
            <div
              class="hidden dropdown-menu right-0"
              id={"dropdownMenu_#{@group.resource_id}_#{@option["id"]}"}
              phx-click-away={close_actions(@group.resource_id, @option["id"], false)}
              aria-labelledby={"dropdownMenuButton_#{@group.resource_id}_#{@option["id"]}"}
            >
              <button
                type="button"
                class="dropdown-item"
                phx-click="show_edit_option_modal"
                phx-value-resource-id={@group.resource_id}
                phx-value-option-id={@option["id"]}
              >
                <i class="fa-solid fa-pencil mr-1"></i> Edit
              </button>
              <div class="dropdown-divider"></div>
              <button
                type="button"
                class="dropdown-item text-danger"
                phx-click="show_delete_option_modal"
                phx-value-resource-id={@group.resource_id}
                phx-value-option-id={@option["id"]}
              >
                <i class="fa-solid fa-trash mr-1"></i> Delete
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </ReorderableList.item>
    """
  end

  attr :group, :any, required: true
  attr :position, :integer, required: true

  def option_drop_target(assigns) do
    ~H"""
    <li
      id={"option-drop-target-#{@group.resource_id}-#{@position}"}
      phx-hook="DropTarget"
      data-drop-index={@position}
      data-reorder-event="reorder_option"
      data-reorder-resource-id={@group.resource_id}
      data-reorder-scope={"alternatives-#{@group.resource_id}"}
      class="drop-target alternatives-option-drop-target list-unstyled"
      aria-hidden="true"
    />
    """
  end

  defp toggle_actions(resource_id, option_id) do
    menu = "#dropdownMenu_#{resource_id}_#{option_id}"
    button = "#dropdownMenuButton_#{resource_id}_#{option_id}"

    JS.toggle(to: menu)
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: button)
  end

  defp close_actions(resource_id, option_id, restore_focus?) do
    menu = "#dropdownMenu_#{resource_id}_#{option_id}"
    button = "#dropdownMenuButton_#{resource_id}_#{option_id}"

    js = JS.hide(to: menu) |> JS.set_attribute({"aria-expanded", "false"}, to: button)

    if restore_focus?, do: JS.focus(js, to: button), else: js
  end
end

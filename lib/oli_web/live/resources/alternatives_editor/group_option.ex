defmodule OliWeb.Resources.AlternativesEditor.GroupOption do
  use Phoenix.Component

  alias OliWeb.Components.ReorderableList
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  attr :group, :any, required: true
  attr :show_actions, :boolean, default: true
  attr :list_class, :string, default: "flex flex-col gap-0"

  def option_list(assigns) do
    assigns = assign(assigns, :option_count, length(assigns.group.content["options"]))

    ~H"""
    <ReorderableList.status id={"alternatives-reorder-status-#{@group.resource_id}"} />
    <ul id={"alternatives-options-#{@group.resource_id}"} class={@list_class}>
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
        "relative flex items-center rounded-md border border-gray-200 bg-white p-3 text-gray-900 shadow-sm transition-colors dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100",
        @show_actions &&
          "cursor-grab active:cursor-grabbing focus:outline-none focus-visible:border-primary-500 focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-1 dark:focus-visible:ring-offset-gray-900"
      ]}
      phx-value-resource-id={@group.resource_id}
      phx-value-option-id={@option["id"]}
      data-reorder-item-id={@option["id"]}
      data-reorder-resource-id={@group.resource_id}
      data-reorder-scope={"alternatives-#{@group.resource_id}"}
      aria-label={@option["name"]}
    >
      <div class="flex min-w-0 flex-1 items-center">
        <i
          :if={@show_actions}
          class="fa-solid fa-grip-vertical mr-3 text-xs text-gray-300 dark:text-gray-600"
          aria-hidden="true"
        >
        </i>
        <div class="min-w-0 flex-1 truncate">{@option["name"]}</div>
        <%= if @show_actions do %>
          <div
            id={"alternatives-option-actions-#{@group.resource_id}-#{@option["id"]}"}
            draggable="true"
            class="relative ml-3 shrink-0"
            ondragstart="event.preventDefault(); event.stopPropagation();"
            phx-keydown={close_actions(@group.resource_id, @option["id"], true)}
            phx-key="Escape"
          >
            <Button.button
              id={"dropdownMenuButton_#{@group.resource_id}_#{@option["id"]}"}
              variant={:text}
              size={:sm}
              class="!h-8 !w-8 !min-w-0 !p-0"
              type="button"
              aria-label="Options"
              title="Options"
              aria-expanded="false"
              aria-controls={"dropdownMenu_#{@group.resource_id}_#{@option["id"]}"}
              phx-click={toggle_actions(@group.resource_id, @option["id"])}
            >
              <Icons.vertical_dots class="h-5 w-5 text-gray-700 dark:text-gray-100" />
            </Button.button>
            <div
              class="absolute right-0 top-full z-20 mt-1 hidden min-w-[9rem] overflow-hidden rounded-md border border-gray-200 bg-white py-1 shadow-lg dark:border-gray-700 dark:bg-gray-800"
              id={"dropdownMenu_#{@group.resource_id}_#{@option["id"]}"}
              phx-click-away={close_actions(@group.resource_id, @option["id"], false)}
              aria-labelledby={"dropdownMenuButton_#{@group.resource_id}_#{@option["id"]}"}
            >
              <button
                type="button"
                class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none dark:text-gray-100 dark:hover:bg-gray-700 dark:focus:bg-gray-700"
                phx-click="show_edit_option_modal"
                phx-value-resource-id={@group.resource_id}
                phx-value-option-id={@option["id"]}
              >
                <i class="fa-solid fa-pencil w-4 text-center" aria-hidden="true"></i> Edit
              </button>
              <div class="my-1 h-px bg-gray-200 dark:bg-gray-700"></div>
              <button
                type="button"
                class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-red-600 hover:bg-red-50 focus:bg-red-50 focus:outline-none dark:text-red-400 dark:hover:bg-red-950/40 dark:focus:bg-red-950/40"
                phx-click="show_delete_option_modal"
                phx-value-resource-id={@group.resource_id}
                phx-value-option-id={@option["id"]}
              >
                <i class="fa-solid fa-trash w-4 text-center" aria-hidden="true"></i> Delete
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
      class="drop-target alternatives-option-drop-target list-none"
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

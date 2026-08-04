defmodule OliWeb.Resources.AlternativesEditor.GroupOption do
  use Phoenix.Component

  import OliWeb.Common.Components

  attr :group, :any, required: true
  attr :show_actions, :boolean, default: true
  attr :list_class, :string, default: "list-group"

  def option_list(assigns) do
    assigns = assign(assigns, :option_count, length(assigns.group.content["options"]))

    ~H"""
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
    <li
      id={"alternatives-option-#{@group.resource_id}-#{@option["id"]}"}
      class={["list-group-item", @show_actions && "cursor-grab active:cursor-grabbing"]}
      draggable={if @show_actions, do: "true", else: "false"}
      phx-hook={@show_actions && "DragSource"}
      data-drag-index={@position}
      data-reorder-item-id={@option["id"]}
      data-reorder-resource-id={@group.resource_id}
      data-reorder-scope={"alternatives-#{@group.resource_id}"}
    >
      <div class="d-flex flex-row align-items-center">
        <div
          :if={@show_actions}
          class="mr-3 text-xs text-gray-300 dark:text-gray-600"
          aria-hidden="true"
        >
          <i class="fa-solid fa-grip-vertical"></i>
        </div>
        <div>{@option["name"]}</div>
        <span
          :if={@show_actions}
          id={"option-position-#{@group.resource_id}-#{@option["id"]}"}
          class="sr-only"
          aria-live="polite"
        >
          {@option["name"]} position {@position + 1} of {@option_count}
        </span>
        <div class="flex-grow-1"></div>
        <%= if @show_actions do %>
          <div
            draggable="true"
            class="d-flex flex-row align-items-center"
            ondragstart="event.preventDefault(); event.stopPropagation();"
          >
            <button
              type="button"
              class="btn icon-button mr-1"
              aria-label={"Move #{@option["name"]} up"}
              disabled={@position == 0}
              phx-click={
                Phoenix.LiveView.JS.push("reorder_option",
                  value: %{
                    resourceId: @group.resource_id,
                    optionId: @option["id"],
                    dropIndex: @position - 1
                  }
                )
              }
            >
              <i class="fa-solid fa-arrow-up" aria-hidden="true"></i>
            </button>
            <button
              type="button"
              class="btn icon-button mr-1"
              aria-label={"Move #{@option["name"]} down"}
              disabled={@position == @option_count - 1}
              phx-click={
                Phoenix.LiveView.JS.push("reorder_option",
                  value: %{
                    resourceId: @group.resource_id,
                    optionId: @option["id"],
                    dropIndex: @position + 2
                  }
                )
              }
            >
              <i class="fa-solid fa-arrow-down" aria-hidden="true"></i>
            </button>
            <.icon_button
              class="mr-1"
              icon="fa-solid fa-pencil"
              on_click="show_edit_option_modal"
              values={[
                "phx-value-resource-id": @group.resource_id,
                "phx-value-option-id": @option["id"]
              ]}
            />
            <.icon_button
              class="danger-icon-button mr-1"
              icon="fa-solid fa-trash"
              on_click="show_delete_option_modal"
              values={[
                "phx-value-resource-id": @group.resource_id,
                "phx-value-option-id": @option["id"]
              ]}
            />
          </div>
        <% end %>
      </div>
    </li>
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
end

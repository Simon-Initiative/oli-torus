defmodule OliWeb.Components.HierarchySelector do
  @moduledoc """
  Hierarchy Selector Component

  ## Required props:
  id:             Unique identifier for the hierarchy selector.
  items:          The items that can be selected.
  on_change:      The function that will be called when the selected items change.
  form:           The changeset that will be updated with the selected items.
  for:            The field in the changeset that will be updated with the selected items.

  ## Optional props:
  selected_values:   The items that are selected by default.
  disabled:         If true, the hierarchy selector will be disabled.
  """
  use OliWeb, :live_component

  def update(assigns, socket) do
    assigns =
      if is_nil(socket.assigns[:mounted]) do
        Map.merge(
          assigns,
          %{
            selected_values: Map.get(assigns, :initial_values, []),
            disabled: Map.get(assigns, :disabled, false),
            mounted: true,
            expanded: assigns[:expanded] || false
          }
        )
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  attr(:items, :list, required: true)
  attr(:disabled, :boolean, required: false, default: false)
  attr(:field_name, :string, required: true)
  attr(:initial_values, :list, required: false, default: [])

  attr(:mounted, :boolean, default: false)
  attr(:expanded, :boolean, default: false)
  attr(:selected_values, :list, default: [])

  def render(assigns) do
    ~H"""
    <div id={@id} class="hierarchy-selector" phx-hook="HierarchySelector">
      <div
        phx-click="expand"
        phx-target={@myself}
        tabindex="0"
        class={"hierarchy-selector__selected-items #{if @disabled, do: "disabled"}"}
      >
        <div
          :for={{item_name, _item_id} <- @selected_values}
          class="hierarchy-selector__selected-item"
        >
          {item_name}
        </div>
      </div>
      <div class="hierarchy-selector__list-container">
        <select hidden name={@field_name} multiple>
          <option :for={{_item_name, item_id} <- @selected_values} selected value={item_id} />
        </select>
        <div
          id={"hierarchy-selector__list-#{@id}"}
          data-active={"#{@expanded}"}
          class="hierarchy-selector__list"
          phx-update="ignore"
        >
          <%= for item <- @items do %>
            {render_resource_option(Map.merge(assigns, %{item: item, level: 0}))}
          <% end %>
        </div>
        <div class="bg-transparent h-5" />
      </div>
    </div>
    """
  end

  defp render_resource_option(assigns) do
    ~H"""
    <div
      class="hierarchy-selector__item"
      id={"hierarchy-selector__item-#{@item.id}"}
      data-expanded="false"
      style={"margin-left: #{6 * @level}px"}
    >
      <div class="flex gap-2 items-center">
        <button
          class={"hierarchy-selector__expand-button #{if length(@item.children) == 0, do: "hidden"}"}
          type="button"
          onclick={"expandElement('hierarchy-selector__item-#{@item.id}')"}
        >
          <i class="fa-solid fa-caret-down h-4 w-4" data-icon="caret-down" />
          <i class="fa-solid fa-caret-up h-4 w-4" data-icon="caret-up" />
        </button>
        <input
          type="checkbox"
          phx-click="select"
          phx-target={@myself}
          id={"hierarchy-selector__checkbox-#{@item.id}"}
          class="form-check-input"
          phx-value-item={"#{@item.name}-#{@item.id}"}
        />
        <label for={"hierarchy-selector__checkbox-#{@item.id}"}>{@item.name}</label>
      </div>
      <div class="hierarchy-selector__item-children">
        <%= for children_item <- @item.children do %>
          {render_resource_option(Map.merge(assigns, %{item: children_item, level: @level + 1}))}
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("expand", _params, socket) do
    socket = assign(socket, expanded: !socket.assigns.expanded)
    {:noreply, socket}
  end

  def handle_event("select", %{"item" => item} = params, socket) do
    [_, item_name, item_id] = Regex.run(~r"(.*)-(\d+)", item)
    checked = Map.get(params, "value", "false")

    if checked === "on" do
      selected_values = socket.assigns.selected_values ++ [{item_name, item_id}]

      socket =
        assign(
          socket,
          selected_values: selected_values
        )

      {:noreply, socket}
    else
      selected_values =
        Enum.reject(socket.assigns.selected_values, fn {_, id} -> item_id == id end)

      socket =
        assign(
          socket,
          selected_values: selected_values
        )

      {:noreply, socket}
    end
  end

  def handle_event("validate-options", _params, socket) do
    {:noreply, socket}
  end
end

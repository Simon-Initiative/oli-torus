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
  use Surface.LiveComponent

  alias Surface.Components.Form.Checkbox

  prop items, :struct, required: true
  prop disabled, :boolean, required: false, default: false
  prop form, :form, from_context: {Surface.Components.Form, :form}
  prop field, :any, from_context: {Surface.Components.Form.Field, :field}
  prop initial_values, :list, required: false, default: []

  data mounted, :boolean, default: false
  data expanded, :boolean, default: false
  data selected_values, :list, default: []

  def update(assigns, socket) do
    assigns =
      if not socket.assigns.mounted do
        assigns
        |> Map.put(
          :selected_values,
          Map.get(assigns, :initial_values, [])
        )
        |> Map.put(
          :disabled,
          Map.get(assigns, :disabled, false)
        )
        |> Map.put(
          :form,
          Map.get(assigns, :form, "")
        )
        |> Map.put(
          :field,
          Map.get(assigns, :field, "")
        )
        |> Map.put(
          :mounted,
          true
        )
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~F"""
    <div id={@id} class="hierarchy-selector" phx-hook="HierarchySelector">
      <div
        phx-target={@myself}
        phx-click="expand"
        tabindex="0"
        class={"hierarchy-selector__selected-items #{if @disabled, do: "disabled"}"}
      >
        {#for {item_name, _item_id} <- @selected_values}
          <div class="hierarchy-selector__selected-item">
            {item_name}
          </div>
        {/for}
      </div>
      <div class="hierarchy-selector__list-container">
        <select hidden name={"#{input_name(@form, @field)}[]"} multiple>
          {#for {_item_name, item_id} <- @selected_values}
            <option selected value={item_id} />
          {/for}
        </select>
        <div id={"hierarchy-selector__list-#{@id}"} data-active={"#{@expanded}"} class="hierarchy-selector__list" phx-update="ignore">
          {#for item <- @items}
            {render_resource_option(assigns, item, 0)}
          {/for}
        </div>
        <div class="bg-transparent h-5" />
      </div>
    </div>
    """
  end

  defp render_resource_option(assigns, item, level) do
    ~F"""
    <div
      class="hierarchy-selector__item"
      id={"hierarchy-selector__item-#{item.id}"}
      data-expanded="false"
      style={"margin-left: #{6 * level}px"}
    >
      <div class="flex gap-2 items-center">
        <button
          class={"hierarchy-selector__expand-button #{if length(item.children) == 0, do: "hidden"}"}
          type="button"
          onclick={"expandElement('hierarchy-selector__item-#{item.id}')"}
        >
          <i class="fa-solid fa-caret-down h-4 w-4" data-icon="caret-down" />
          <i class="fa-solid fa-caret-up h-4 w-4" data-icon="caret-up" />
        </button>
        <Checkbox
          value={Enum.member?(@selected_values, {item.name, "#{item.id}"})}
          opts={["phx-target": @myself, "phx-value-item": "#{item.name}-#{item.id}"]}
          click="select"
          id={"hierarchy-selector__checkbox-#{item.id}"}
          class="form-check-input"
        />
        <label>{item.name}</label>
      </div>
      <div class="hierarchy-selector__item-children">
        {#for children_item <- item.children}
          {render_resource_option(assigns, children_item, level + 1)}
        {/for}
      </div>
    </div>
    """
  end

  def handle_event("expand", _params, socket) do
    socket = assign(socket, expanded: not socket.assigns.expanded)
    {:noreply, socket}
  end

  def handle_event("select", %{"item" => item} = params, socket) do
    [_, item_name, item_id] = Regex.run(~r"(.*)-(\d+)", item)
    checked = Map.get(params, "value", "false")

    if checked === "true" do
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

  defp input_name(%{name: nil}, field), do: to_string(field)

  defp input_name(%{name: name}, field) when is_atom(field) or is_binary(field),
    do: "#{name}[#{field}]"

  defp input_name(name, field) when (is_atom(name) and is_atom(field)) or is_binary(field),
    do: "#{name}[#{field}]"
end

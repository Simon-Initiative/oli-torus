defmodule OliWeb.Components.Tag do
  use Phoenix.Component

  attr :color, :string, default: "red"
  slot :inner_block, required: true

  def render(assigns) do
    assigns = assign(assigns, :class, "bg-#{assigns.color}-500 text-white text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-#{assigns.color}-500 dark:text-white border border-#{assigns.color}-500")
    ~H"""
      <span class={@class}>
        <%= render_slot(@inner_block) %>
      </span>
    """
  end
end

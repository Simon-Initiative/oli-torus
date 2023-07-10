defmodule OliWeb.Components.Tag do
  use Phoenix.Component

  attr :color, :string, default: "red"
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
      <span class={"bg-#{@color}-500 text-white text-xs font-medium mr-2 px-2.5 py-0.5 rounded dark:bg-#{@color}-500 dark:text-white border border-#{@color}-500"}>
        <%= render_slot(@inner_block) %>
      </span>
    """
  end
end

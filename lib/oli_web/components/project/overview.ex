defmodule OliWeb.Components.Overview do
  use Phoenix.Component

  slot :inner_block, required: true
  attr :title, :string, required: true
  attr :description, :string, required: false
  attr :is_last, :boolean, required: false

  def section(assigns) do
    ~H"""
    <div class={"grid grid-cols-12 py-5 #{if !assigns[:is_last], do: "border-b dark:border-gray-700"}"}>
      <div class="col-span-4 mr-4">
        <h4>{@title}</h4>
        <%= if assigns[:description] do %>
          <div class="text-muted">{@description}</div>
        <% end %>
      </div>
      <div class="col-span-8">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

defmodule OliWeb.Common.Properties.Group do
  use OliWeb, :html

  attr :label, :string, required: true
  attr :label_class, :string, default: ""
  attr :description, :string, default: ""
  attr :is_last, :boolean, default: false
  attr :description_class, :string, default: ""

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class={"flex flex-col md:grid md:grid-cols-12 py-5 last:border-none #{if !@is_last, do: "border-b dark:border-gray-700"}"}>
      <div class="md:col-span-4">
        <h4 class={@label_class}>{@label}</h4>
        <%= if @description != "" do %>
          <div class={if @description_class != "", do: @description_class, else: "text-muted"}>
            {@description}
          </div>
        <% end %>
      </div>
      <div class="md:col-span-8">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

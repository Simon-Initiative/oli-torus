defmodule OliWeb.Common.Properties.Group do
  use OliWeb, :html

  attr :label, :string, required: true
  attr :description, :string, default: ""
  attr :is_last, :boolean, default: false

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class={"grid grid-cols-12 py-5 last:border-none #{if !@is_last, do: "border-b dark:border-gray-700"}"}>
      <div class="md:col-span-4">
        <h4><%= @label %></h4>
        <%= if @description != "" do %>
          <div class="text-muted">
            <%= @description %>
          </div>
        <% end %>
      </div>
      <div class="md:col-span-8">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end

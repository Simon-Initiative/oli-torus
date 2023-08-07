defmodule OliWeb.Common.Properties.Group do
  use Surface.Component

  attr :label, :string, required: true
  attr :description, :string, default: ""
  attr :is_last, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class={"grid grid-cols-12 py-5 #{if !@is_last, do: "border-b dark:border-gray-700"}"}>
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

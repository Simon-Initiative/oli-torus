defmodule OliWeb.Components.Delivery.AssignmentCard do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
      <div class="flex justify-between items-center bg-delivery-header p-8">
        <h3 class="text-white text-xl"><%= @assignment.title %></h3>
        <div class="flex gap-2">
          <span class="bg-white bg-opacity-10 rounded-sm text-white text-center w-56 py-2">
            <%= if @assignment.end_date do %>
              Due by <%= @assignment.end_date %>
            <% else %>
              No due date
            <% end %>
          </span>
          <button class="torus-button primary px-2">Quiz</button>
        </div>
      </div>
    """
  end
end

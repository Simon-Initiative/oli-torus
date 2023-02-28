defmodule OliWeb.Components.Delivery.PageDelivery do
  use Phoenix.Component

  attr(:title, :string, required: true)
  attr(:page_number, :integer, required: true)
  attr(:review_mode, :boolean, required: true)

  def header(assigns) do
    ~H"""
      <h1 class="title flex flex-row justify-between">
        <%= @title %><%= if @review_mode == true do %>
          (Review)
        <% end %>
        <div class="page-number text-gray-500">
          <%= @page_number %>
        </div>
      </h1>
    """
  end

  def details(assigns) do
    ~H"""
      <div class="flex flex-row my-2">
        <div class="py-1.5 px-4 bg-gray-100 text-gray-700 rounded">
          Read by 10-03-2022
        </div>
        <div class="py-1.5 px-4 bg-gray-100 text-gray-700 rounded ml-1">
          Estimated reading time: 5 mins
        </div>
      </div>
    """
  end

  attr(:objectives, :list, required: true)

  def learning_objectives(assigns) do
    ~H"""
      <%= if length(@objectives) > 0 do %>
        <div class="objectives py-4">
          <div class="uppercase font-bold mb-2">Learning Objectives</div>
          <ul class="list-none">
            <%= for title <- @objectives do %>
              <li class="objective mt-2"><%= title %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
    """
  end
end

defmodule OliWeb.Components.Delivery.PageDelivery do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils

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

  attr :scheduling_type, :atom, values: [:read_by, :inclass_activity]
  attr :end_date, Date, default: nil
  attr :est_reading_time, Timex.Duration, default: nil

  def details(assigns) do
    ~H"""
      <div class="flex flex-row my-2">
        <%= if @end_date do %>
          <div class="py-1.5 px-4 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-delivery-body-color-dark rounded">
            <%= scheduling_type_label(@scheduling_type) %> <%= format_date(@end_date) %>
          </div>
        <% end %>
        <%= if @est_reading_time do %>
          <div class="py-1.5 px-4 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-delivery-body-color-dark rounded ml-1">
            Estimated reading time: <%= format_duration(@est_reading_time) %>
          </div>
        <% end %>
      </div>
    """
  end

  defp scheduling_type_label(:read_by), do: "Read by"
  defp scheduling_type_label(:inclass_activity), do: "In-class activity"

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

defmodule OliWeb.Components.Delivery.AssignmentCard do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  defp due_date_label(assignment) do
    case assignment.gate_type do
      nil -> case assignment.scheduled_type do
        :read_by -> "Suggested by"
        _ -> "In class activity"
      end
      _ -> "Due by"
    end
  end

  def render(assigns) do
    ~H"""
      <div class="flex justify-between items-center bg-delivery-header p-8">
        <h3 class="text-white text-xl"><%= @assignment.title %></h3>
        <div class="flex gap-2">
          <span class="bg-white bg-opacity-10 rounded-sm text-white text-center w-56 py-2">
            <%= if @assignment.end_date do %>
              <%= due_date_label(@assignment) %> <%= @assignment.end_date %>
            <% else %>
              No due date
            <% end %>
          </span>
          <a class="torus-button primary px-2" href={Routes.page_delivery_path(OliWeb.Endpoint, :page, @section_slug, @assignment.slug)}>Open</a>
        </div>
      </div>
    """
  end
end

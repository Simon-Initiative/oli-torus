defmodule OliWeb.Components.Delivery.AssignmentCard do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  defp due_date_label(assignment) do
    case assignment.gate_type do
      nil ->
        case assignment.scheduled_type do
          :read_by -> "Suggested by"
          _ -> "In class activity"
        end

      _ ->
        "Due by"
    end
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col">
        <div class="flex justify-between items-center bg-delivery-header p-8">
          <div class="flex gap-2">
            <button disabled={length(@assignment.relates_to) < 1} class="disabled:opacity-30 disabled:pointer-events-none group collapsed" data-bs-toggle="collapse" data-bs-target={"#assignment-#{@assignment.id}"}>
              <i class="fa-solid fa-caret-down text-white hidden group-[.collapsed]:block" />
              <i class="fa-solid fa-caret-up text-white block group-[.collapsed]:hidden" />
            </button>
            <h3 class="text-white text-xl"><%= @assignment.title %></h3>
          </div>
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

        <%= if length(@assignment.relates_to) > 0 do %>
          <div id={"assignment-#{@assignment.id}"} class="bg-white flex flex-col collapse">
            <div class="px-8 py-3 border-b border-b-gray-200">
              <p class="font-bold uppercase m-0">Quiz covers</p>
            </div>

            <%= if has_foundational_pages?(@assignment) do %>
              <div class="px-8 py-3 border-b border-b-gray-200 flex flex-col">
                <div class="bg-green-700 text-white w-40 text-center py-1 px-5 mb-5 rounded-full">Course content</div>
                <table class="border-none">
                <tbody>
                  <%= for page <- @assignment.relates_to |> Enum.filter(&(&1.purpose == :foundation)) do %>
                    <.render_related_page_info section_slug={@section_slug} page={page} />
                  <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>

            <%= if has_exploration_pages?(@assignment) do %>
              <div class="px-8 py-3 border-b border-b-gray-200 flex flex-col">
                <div class="bg-primary text-white w-40 text-center py-1 px-5 mb-5 rounded-full">Explorations</div>
                <table class="border-none">
                <tbody>
                  <%= for page <- @assignment.relates_to |> Enum.filter(&(&1.purpose == :application)) do %>
                    <.render_related_page_info section_slug={@section_slug} page={page} />
                  <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    """
  end

  def render_related_page_info(assigns) do
    ~H"""
      <tr class="border-b border-b-gray-200 last:border-b-0">
        <td class="w-1/3 border-none"><%= @page.title %></td>
        <td class={"w-1/3 border-none text-center #{if !@page.progress, do: "text-red-600"}"}>
          <%= if @page.progress do %>
            <%= @page.progress %>% Completed
          <% else %>
            Not attempted
          <% end %>
        </td>
        <td class="w-1/3 border-none text-right">
          <a href={Routes.page_delivery_path(OliWeb.Endpoint, :page, @section_slug, @page.slug)}>Open</a>
        </td>
      </tr>
    """
  end

  defp has_exploration_pages?(assignment) do
    Enum.find(assignment.relates_to, &(&1.purpose == :application))
  end

  defp has_foundational_pages?(assignment) do
    Enum.find(assignment.relates_to, &(&1.purpose == :foundation))
  end
end

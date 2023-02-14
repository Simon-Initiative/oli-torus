defmodule OliWeb.Components.Delivery.ExplorationShade do
  use Phoenix.Component

  def exploration_shade(assigns) do
    assigns = assign(assigns, exploration_pages: Map.get(assigns, :exploration_pages, nil))
    ~H"""
      <div class="bg-delivery-header text-white border-b border-slate-300">
        <div class="container mx-auto md:px-10 py-2 flex flex-row justify-between text-sm md:text-lg">
          <div class="flex items-center gap-2">
            <h4 class="p-2 md:p-0 md:leading-loose">
              Your Exploration Activities
            </h4>
            <%= if not is_nil(@exploration_pages) and length(@exploration_pages) > 0 do %>
              <span class="badge badge-info rounded-full"><%= length(@exploration_pages) %></span>
            <% end %>
          </div>

          <div>
            <button class="btn group" data-bs-toggle="collapse" data-bs-target="#collapseExploration" aria-expanded="false" aria-controls="collapseExploration">
              <span class="hidden md:inline mr-2">Expand</span><i class="fa-solid fa-circle-chevron-down group-aria-expanded:rotate-180"></i>
            </button>
          </div>
        </div>
        <div class="collapse container mx-auto md:px-10 py-2" id="collapseExploration">
          <%= if not is_nil(@exploration_pages) and length(@exploration_pages) > 0 do %>
            <!-- TODO: Add the expandable components implemented in MER-1674 once it gets merged -->
            <%= for page <- @exploration_pages |> IO.inspect() do %>
              <p><%= page.title %></p>
            <% end %>
          <% else %>
              <p class="italic">There are no explorations related to this page</p>
          <% end %>
        </div>
      </div>
    """
  end
end

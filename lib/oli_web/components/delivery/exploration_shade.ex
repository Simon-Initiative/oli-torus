defmodule OliWeb.Components.Delivery.ExplorationShade do
  use Phoenix.Component

  alias OliWeb.Components.Delivery.ExplorationCard

  attr :exploration_pages, :map, default: nil
  attr :section_slug, :string
  attr :title, :string

  def exploration_shade(assigns) do
    ~H"""
    <div class="text-white bg-delivery-instructor-dashboard-header border-b border-slate-300">
      <div class="container mx-auto md:px-10 py-2 flex flex-row justify-between text-sm md:text-lg">
        <div class="flex items-center gap-2">
          <h4 class="p-2 md:p-0 md:leading-loose">
            Your Exploration Activities
          </h4>
          <%= if @exploration_pages && length(@exploration_pages) > 0 do %>
            <span class="badge badge-info rounded-full">{length(@exploration_pages)}</span>
          <% end %>
        </div>

        <div>
          <button
            class="btn group"
            data-bs-toggle="collapse"
            data-bs-target="#collapseExploration"
            aria-expanded="false"
            aria-controls="collapseExploration"
          >
            <span class="hidden md:inline mr-2">Expand</span><i class="fa-solid fa-circle-chevron-down group-aria-expanded:rotate-180"></i>
          </button>
        </div>
      </div>
      <div class="collapse container mx-auto md:px-10 pt-2 pb-4" id="collapseExploration">
        <%= if @exploration_pages && length(@exploration_pages) > 0 do %>
          <div class="grid grid-cols-1 md:grid-cols-1 gap-4 max-h">
            <%= for exploration <- @exploration_pages do %>
              <ExplorationCard.render
                dark={true}
                exploration={exploration}
                section_slug={@section_slug}
              />
            <% end %>
          </div>
        <% else %>
          <p class="text-white italic">There are no explorations related to this page</p>
        <% end %>
      </div>
    </div>
    """
  end
end

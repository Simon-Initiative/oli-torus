defmodule OliWeb.Components.Delivery.ExplorationShade do
  use Phoenix.Component

  def exploration_shade(assigns) do
    ~H"""
      <div class="bg-delivery-header text-white border-b border-slate-300">
        <div class="container mx-auto md:px-10 py-2 flex flex-row justify-between text-sm md:text-lg">
          <h4 class="p-2 md:p-0 md:leading-loose">
            Your Exploration Activities
          </h4>

          <div>
            <button class="btn group" data-bs-toggle="collapse" data-bs-target="#collapseExploration" aria-expanded="false" aria-controls="collapseExploration">
              <span class="hidden md:inline mr-2">Expand</span><i class="fa-solid fa-circle-chevron-down group-aria-expanded:rotate-180"></i>
            </button>
          </div>
        </div>
        <div class="collapse container mx-auto md:px-10 py-2" id="collapseExploration">
          EXAMPLE EXPLORATION CONTENT
        </div>
      </div>
    """
  end
end

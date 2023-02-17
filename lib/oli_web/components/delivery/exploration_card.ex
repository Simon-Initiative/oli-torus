defmodule OliWeb.Components.Delivery.ExplorationCard do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
      <div class="bg-white dark:bg-gray-800 shadow">
        <div class="p-6 flex flex-col lg:flex-row items-center justify-between">
          <div class="flex flex-col my-3 gap-y-3">
            <h6 class="font-semibold text-lg leading-6"><%= @exploration.title %></h6>
            <div class="flex items-center">
              <div class="flex items-center gap-1">
                <div class="text-delivery-primary"><i class="fa-solid fa-clock"></i></div>
                <span class="font-normal text-sm leading-5">Estimated completion time: 10 mins</span>
              </div>
            </div>
          </div>
          <div class="flex gap-3 items-stretch">
            <div class="flex lg:w-64 bg-gray-100 items-center justify-center"><span class="py-2 px-5">Completed!</span></div>
            <button class="btn text-white hover:text-white inline-flex ml-2 bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700">Review</button>
          </div>
        </div>
      </div>
    """
  end
end

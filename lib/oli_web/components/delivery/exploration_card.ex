defmodule OliWeb.Components.Delivery.ExplorationCard do
  use Phoenix.Component

  attr :dark, :boolean, default: false
  attr :exploration, :map

  def render(assigns) do
    ~H"""
      <div class={"@container/card flex-1 bg-white dark:bg-gray-800 dark:text-white shadow #{if @dark, do: "bg-delivery-header-800 text-white"}"}>
        <div class="p-6 flex flex-col">
          <h6 class="font-semibold text-lg leading-6"><%= @exploration.title %></h6>
          <div class="flex flex-col @2xl/card:flex-row @2xl/card:items-center @2xl/card:justify-between">
            <div class="flex w-full flex-col my-3 gap-y-3">
              <div class="flex items-center">
                <div class="flex items-center gap-1">
                  <div class="text-delivery-primary"><i class="fa-solid fa-clock"></i></div>
                  <span class="font-normal text-sm leading-5">Estimated completion time: 10 mins</span>
                </div>
              </div>
            </div>
            <div class="flex w-full gap-3 justify-end">
              <div class={"flex flex-1 @2xl/card:flex-initial @2xl/card:w-64 bg-gray-100 items-center justify-center rounded-sm #{if @dark, do: "bg-opacity-10"}"}>
                <span class="py-2 px-5">Completed!</span>
              </div>
              <button class="btn text-white hover:text-white inline-flex bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700">Review</button>
            </div>
          </div>
        </div>
      </div>
    """
  end
end

defmodule OliWeb.Common.Filter do
  use Surface.Component

  prop change, :event, required: true
  prop apply, :event, required: true
  prop reset, :event, required: true
  prop query, :string

  def render(assigns) do
    ~F"""
      <div class="input-group search-input flex gap-2">
        <div class="relative flex flex-1 items-center">
          <input type="text" class="form-control h-full pr-6" placeholder="Search..." :on-change={@change} :on-blur={@change} value={@query} />
          <button id="reset_search" :on-click={@reset} phx-type="button" class="absolute my-auto right-2 h-6 w-6 rounded-full hover:bg-delivery-primary-100 hover:text-white">
            <i class="fa-solid fa-xmark" />
          </button>
        </div>
        <button class="btn btn-outline-secondary border-none text-white bg-delivery-primary hover:bg-delivery-primary-400 active:bg-delivery-primary-600" :on-click={@apply} phx-type="button">Search</button>
      </div>
    """
  end
end

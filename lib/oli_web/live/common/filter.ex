defmodule OliWeb.Common.Filter do
  use Surface.Component

  prop change, :event, required: true
  prop apply, :event, required: true
  prop reset, :event, required: true
  prop query, :string

  def render(assigns) do
    ~F"""
      <div class="input-group" style="max-width: 500px;">
        <input type="text" class="form-control" placeholder="Search..." :on-change={@change} :on-blur={@change} value={@query}>
        <div class="input-group-append">
          <button class="btn btn-outline-secondary" :on-click={@apply} phx-type="button">Search</button>
          <button class="btn btn-outline-secondary" :on-click={@reset} phx-type="button">Reset</button>
        </div>
      </div>
    """
  end
end

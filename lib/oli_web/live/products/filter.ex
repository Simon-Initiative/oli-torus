defmodule OliWeb.Products.Filter do
  use Surface.LiveComponent

  prop change, :event, required: true
  prop reset, :event, required: true

  data text, :string, default: ""

  def render(assigns) do
    ~F"""
      <div class="input-group" style="max-width: 500px;">
        <input type="text" class="form-control" placeholder="Search..." :on-change="change" :on-blur="change">
        <div class="input-group-append">
          <button class="btn btn-outline-secondary" :on-click={@change} phx-value-text={@text} phx-type="button">Search</button>
          <button class="btn btn-outline-secondary" :on-click={@reset} phx-type="button">Reset</button>
        </div>
      </div>
    """
  end

  def handle_event("change", %{"value" => text}, socket) do
    {:noreply, assign(socket, text: text)}
  end
end

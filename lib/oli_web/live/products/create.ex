defmodule OliWeb.Products.Create do
  use Surface.LiveComponent

  prop title, :string, required: true
  prop click, :event, required: true
  prop change, :event, required: true

  def render(assigns) do
    ~F"""
    <div>
      <p>Create a new product with title:</p>
      <input type="text" style="width: 40%;" :on-blur={@change} :on-keyup={@change}>

      <button class="btn btn-primary" :on-click={@click} disabled={@title == ""}>Create Product</button>
    </div>
    """
  end
end

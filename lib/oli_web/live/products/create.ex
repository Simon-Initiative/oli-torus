defmodule OliWeb.Products.Create do
  use OliWeb, :html

  attr(:title, :string, required: true)
  attr(:click, :any, required: true)
  attr(:change, :any, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <p>Create a new product with title:</p>
      <input type="text" style="width: 40%;" phx-blur={@change} phx-keyup={@change} />

      <button class="btn btn-primary" phx-click={@click} disabled={@title == ""}>
        Create Product
      </button>
    </div>
    """
  end
end

defmodule OliWeb.Products.Create do
  use OliWeb, :html

  attr(:title, :string, required: true)
  attr(:click, :any, required: true)
  attr(:change, :any, required: true)

  def render(assigns) do
    ~H"""
    <div class="px-4 py-3">
      <p>Create a new product with title:</p>
      <input type="text" style="width: 40%;" phx-blur={@change} phx-keyup={@change} />

      <button
        id="button-new-project"
        class="btn btn-sm btn-primary ml-2 rounded-md bg-[#0080FF] shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-4 py-2"
        phx-click={@click}
        disabled={@title == ""}
      >
        <i class="fa fa-plus pr-2"></i> Create Product
      </button>
    </div>
    """
  end
end

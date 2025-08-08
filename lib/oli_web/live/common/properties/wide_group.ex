defmodule OliWeb.Common.Properties.WideGroup do
  use Phoenix.Component

  attr :label, :string, required: true
  attr :description, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-12 py-5">
      <div class="md:col-span-12">
        <h4>{@label}</h4>
        <div class="text-muted">
          {@description}
        </div>
      </div>
    </div>
    <div class="grid grid-cols-12 border-b">
      <div class="md:col-span-12">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

defmodule OliWeb.Common.Properties.Groups do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      {render_slot(@inner_block)}
    </div>
    """
  end
end

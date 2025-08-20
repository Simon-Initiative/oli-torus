defmodule OliWeb.ManualGrading.Group do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="mb-3">
      {render_slot(@inner_block)}
    </div>
    """
  end
end

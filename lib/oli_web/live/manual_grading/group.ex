defmodule OliWeb.ManualGrading.Group do
  use Surface.Component

  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="mb-3">
      <#slot />
    </div>
    """
  end
end

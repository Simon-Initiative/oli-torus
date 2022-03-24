defmodule OliWeb.ManualGrading.Group do
  use Surface.Component

  slot default, required: true

  def render(assigns) do
    ~F"""
    <div style="padding: 20px; border: 2px inset rgba(28,110,164,0.17); border-radius: 12px;" class="mb-3">
      <#slot />
    </div>
    """
  end

end

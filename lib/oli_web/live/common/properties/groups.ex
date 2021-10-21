defmodule OliWeb.Common.Properties.Groups do
  use Surface.Component

  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="container">
      <#slot />
    </div>
    """
  end
end

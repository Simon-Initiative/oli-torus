defmodule OliWeb.Common.Properties.WideGroup do
  use Surface.Component

  prop label, :string, required: true
  prop description, :string, required: true
  slot default, required: true

  def render(assigns) do
    ~F"""
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
        <#slot />
      </div>
    </div>
    """
  end
end

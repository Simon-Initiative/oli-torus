defmodule OliWeb.Common.Properties.Group do
  use Surface.Component

  prop label, :string, required: true
  prop description, :string, required: true
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="row py-5 border-bottom">
      <div class="col-md-4">
        <h4>{@label}</h4>
        <div class="text-muted">
          {@description}
        </div>
      </div>
      <div class="col-md-8">
      <#slot />
      </div>
    </div>
    """
  end
end

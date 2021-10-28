defmodule OliWeb.Common.Properties.WideGroup do
  use Surface.Component

  prop label, :string, required: true
  prop description, :string, required: true
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="row py-5">
      <div class="col-md-12">
        <h4>{@label}</h4>
        <div class="text-muted">
          {@description}
        </div>
      </div>
    </div>
    <div class="row border-bottom">
      <div class="col-md-12">
        <#slot />
      </div>
    </div>
    """
  end
end

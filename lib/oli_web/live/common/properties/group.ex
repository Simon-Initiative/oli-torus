defmodule OliWeb.Common.Properties.Group do
  use Surface.Component

  prop label, :string, required: true
  prop description, :string
  prop is_last, :boolean, default: false
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class={"grid grid-cols-12 py-5 #{if !assigns[:is_last], do: "border-b"}"}>
      <div class="md:col-span-4">
        <h4>{@label}</h4>
        {#if assigns[:description]}
          <div class="text-muted">
            {@description}
          </div>
        {/if}
      </div>
      <div class="md:col-span-8">
      <#slot />
      </div>
    </div>
    """
  end
end

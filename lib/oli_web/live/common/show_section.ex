defmodule OliWeb.Common.ShowSection do
  use Surface.Component

  prop section_title, :string, required: true
  prop section_description, :string
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="flex md:grid grid-cols-12 py-5 border-b">
      <div class="md:col-span-4">
        <h4>{@section_title}</h4>
        {#unless is_nil(@section_description)}
          <div class="text-muted">{@section_description}</div>
        {/unless}
      </div>
      <div class="md:col-span-8">
        <#slot />
      </div>
    </div>
    """
  end
end

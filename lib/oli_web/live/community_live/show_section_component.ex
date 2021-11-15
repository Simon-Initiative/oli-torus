defmodule OliWeb.CommunityLive.ShowSectionComponent do
  use Surface.Component

  prop section_title, :string, required: true
  prop section_description, :string
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="row py-5 border-bottom">
      <div class="col-md-4">
        <h4>{@section_title}</h4>
        {#unless is_nil(@section_description)}
          <div class="text-muted">{@section_description}</div>
        {/unless}
      </div>
      <div class="col-md-8">
        <#slot />
      </div>
    </div>
    """
  end
end

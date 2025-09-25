defmodule OliWeb.Common.ShowSection do
  use OliWeb, :html

  attr(:section_title, :string, required: true)
  attr(:section_description, :string, default: nil)
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class="flex md:grid grid-cols-12 py-5 border-b">
      <div class="md:col-span-4">
        <h4>{@section_title}</h4>
        <%= unless is_nil(@section_description) do %>
          <div class="text-muted">{@section_description}</div>
        <% end %>
      </div>
      <div class="md:col-span-8">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

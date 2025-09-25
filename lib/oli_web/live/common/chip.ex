defmodule OliWeb.Common.Chip do
  use Phoenix.Component

  attr :label, :string, required: true
  attr :bg_color, :string, required: true
  attr :text_color, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="inline-flex items-center">
      <div class={"px-2 py-1 rounded-full shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] flex items-center overflow-hidden #{@bg_color}"}>
        <div class="px-2 flex items-center">
          <div class={"text-base font-semibold text-center #{@text_color}"}><%= @label %></div>
        </div>
      </div>
    </div>
    """
  end
end

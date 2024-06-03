defmodule OliWeb.Components.Delivery.CardHighLights do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :is_selected, :boolean, default: false
  attr :value, :string, required: true
  attr :on_click, :map, required: true
  attr :container_filter_by, :atom

  def render(assigns) do
    ~H"""
    <div
      phx-click={@on_click}
      phx-value-selected={@value}
      class={"w-56 h-auto rounded-md #{if @is_selected, do: "shadow border-2 border-blue-500 bg-slate-50", else: "bg-white border border-blue-500/30 hover:border-blue-500/80"} flex-col justify-start items-start px-4 py-3 hover:cursor-pointer"}
    >
      <div class="text-slate-500 text-xs font-normal leading-none">
        <%= @title %>
      </div>
      <div class="flex items-baseline space-x-2 mt-2">
        <div class={"text-3xl font-semibold leading-10 #{if @is_selected, do: "text-blue-500", else: "text-slate-800"}"}>
          <%= @count %>
        </div>
        <div class="text-gray-400 text-xs font-normal leading-none">
          <%= case @container_filter_by do %>
            <% :units -> %>
              Units
            <% :modules -> %>
              Modules
            <% _ -> %>
              Students
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

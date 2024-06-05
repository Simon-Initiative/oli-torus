defmodule OliWeb.Components.Delivery.CardHighlights do
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
      class={"w-56 h-auto rounded-md dark:bg-gray-800 flex-col justify-start items-start px-4 py-3 hover:cursor-pointer #{if @is_selected, do: "shadow border-2 border-blue-500 bg-slate-50", else: "bg-white border border-blue-500/30 hover:border-blue-500/80 dark:border-white"}"}
    >
      <div class="text-slate-500 text-xs font-normal leading-none dark:text-white">
        <%= @title %>
      </div>
      <div class="flex items-baseline space-x-2 mt-2">
        <div class={"text-3xl font-semibold leading-10 dark:text-white #{if @is_selected, do: "text-blue-500", else: "text-slate-800"}"}>
          <%= @count %>
        </div>
        <div class="text-gray-400 text-xs font-normal leading-none dark:text-white">
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

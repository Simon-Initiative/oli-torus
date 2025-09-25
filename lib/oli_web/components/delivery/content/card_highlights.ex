defmodule OliWeb.Components.Delivery.CardHighlights do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :is_selected, :boolean, default: false
  attr :value, :string, required: true
  attr :on_click, :map, required: true
  attr :container_filter_by, :atom, default: nil

  def render(assigns) do
    ~H"""
    <div
      phx-click={@on_click}
      phx-value-selected={@value}
      class={
        "inline-flex flex-col justify-start items-start gap-3 p-6 h-32 rounded-2xl shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]
        outline outline-1 outline-offset-[-1px] outline-gray-300 cursor-pointer transition-colors dark:bg-[#000000] dark:outline-[#3B3740] hover:outline-[#006CD9] hover:dark:outline-[#4CA6FF] " <>
        if @is_selected, do: "bg-[#F2F9FF] outline-[#006CD9] dark:bg-[#0A203A] dark:outline-[#4CA6FF]", else: ""
      }
    >
      <div class="text-gray-700 text-base font-semibold leading-normal dark:text-[#EEEBF5]">
        <%= @title %>
      </div>

      <div class="flex justify-start items-end gap-2 w-full">
        <div class={"text-[32px] font-bold leading-[44px] #{if @is_selected, do: "text-[#006CD9] dark:text-[#4CA6FF]", else: "text-[#353740] dark:text-[#EEEBF5]"}"}>
          <%= @count %>
        </div>
        <div class="flex-1 py-2 flex justify-start items-center gap-1">
          <div class="text-sm text-[#45464c] font-normal leading-none dark:text-[#BAB8BF]">
            <%= label_for(@container_filter_by, @count) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp label_for(type, count) do
    base =
      case type do
        :units -> "Unit"
        :modules -> "Module"
        :students -> "Student"
        _ -> to_string(type || "")
      end

    if count == 1, do: base, else: "#{base}s"
  end
end

defmodule OliWeb.Components.Delivery.CardHighlights do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :is_selected, :boolean, default: false
  attr :value, :any, required: true
  attr :on_click, :map, required: true
  attr :container_filter_by, :any, default: nil

  def render(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_click}
      phx-value-selected={@value}
      aria-pressed={if @is_selected, do: "true", else: "false"}
      class={[
        "inline-flex flex-col justify-start items-start gap-3 p-6 min-h-32 rounded-2xl shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]",
        "outline outline-1 outline-offset-[-1px] outline-gray-300 cursor-pointer transition-colors text-left",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#006CD9]",
        "dark:bg-[#000000] dark:outline-[#3B3740] hover:outline-[#006CD9] hover:dark:outline-[#4CA6FF] focus-visible:dark:outline-[#4CA6FF]",
        @is_selected &&
          "bg-[#F2F9FF] outline-[#006CD9] dark:bg-[#0A203A] dark:outline-[#4CA6FF]"
      ]}
    >
      <div class="text-gray-700 text-base font-semibold leading-normal dark:text-[#EEEBF5]">
        {@title}
      </div>

      <div class="flex justify-start items-end gap-2 w-full">
        <div class={"text-[32px] font-bold leading-[44px] #{if @is_selected, do: "text-[#006CD9] dark:text-[#4CA6FF]", else: "text-[#353740] dark:text-[#EEEBF5]"}"}>
          {@count}
        </div>
        <div class="flex-1 py-2 flex justify-start items-center gap-1">
          <div class="text-sm text-[#45464c] font-normal leading-none dark:text-[#BAB8BF]">
            {label_for(@container_filter_by, @count)}
          </div>
        </div>
      </div>
    </button>
    """
  end

  defp label_for(type, count) do
    base =
      case type do
        :units -> "Unit"
        :modules -> "Module"
        :students -> "Student"
        :pages -> "Page"
        :questions -> "Question"
        _ -> to_string(type || "")
      end

    if count == 1, do: base, else: "#{base}s"
  end
end

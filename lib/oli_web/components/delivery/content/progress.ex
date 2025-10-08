defmodule OliWeb.Delivery.Content.PercentageSelector do
  use OliWeb, :html

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  attr(:id, :string, default: "progress")
  attr(:percentage, :string)
  attr(:target, :any)
  attr(:label, :string, default: "Progress")
  attr(:submit_event, :string, default: "apply_progress_filter")
  attr(:input_name, :string, default: "progress_percentage")

  attr(:selector, :atom,
    values: [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal]
  )

  def render(assigns) do
    assigns = assign(assigns, :selector, assigns.selector || :is_equal_to)

    ~H"""
    <div class="relative !z-50">
      <div
        phx-click={
          JS.toggle(to: "##{@id}_form", display: "flex")
          |> JS.toggle(to: "##{@id}-down-icon")
          |> JS.toggle(to: "##{@id}-up-icon")
        }
        class="w-full h-9"
      >
        <button
          class={[
            "h-full flex-shrink-0 rounded z-10 inline-flex items-center py-2.5 px-2 text-[#353740] text-base font-semibold leading-none",
            "outline outline-1",
            if @percentage not in ["", nil] do
              "outline-[#006CD9] text-[#006CD9] dark:outline-[#4CA6FF] dark:text-[#4CA6FF]"
            else
              "outline-[#ced1d9] dark:text-[#EEEBF5] dark:outline-[#3B3740]"
            end
          ]}
          type="button"
        >
          {@label} {progress_filter_text(@selector, @percentage)}
          <div class="ml-2">
            <.toggle_chevron
              id={@id}
              map_values={if @percentage not in ["", nil], do: @selector, else: %{}}
            />
          </div>
        </button>
      </div>
      <.form
        for={%{}}
        phx-click-away={
          JS.hide(to: "##{@id}_form")
          |> JS.hide(to: "##{@id}-up-icon")
          |> JS.show(to: "##{@id}-down-icon")
        }
        class="hidden bg-white dark:bg-gray-800 mt-1 rounded border flex flex-col p-2 px-4 absolute w-auto"
        phx-submit={@submit_event}
        id={"#{@id}_form"}
        phx-target={@target}
      >
        <div class="progress-options mt-2">
          {radio_button(:progress, :option, "is_equal_to",
            field: "is_equal_to",
            checked: @selector == :is_equal_to,
            id: "#{@id}_is_equal_to"
          )}
          <label for={"#{@id}_is_equal_to"}>is =</label>

          {radio_button(:progress, :option, "is_less_than_or_equal",
            field: "is_less_than_or_equal",
            checked: @selector == :is_less_than_or_equal,
            id: "#{@id}_is_less_than_or_equal"
          )}
          <label for={"#{@id}_is_less_than_or_equal"}>&le;</label>

          {radio_button(:progress, :option, "is_greather_than_or_equal",
            field: "is_greather_than_or_equal",
            checked: @selector == :is_greather_than_or_equal,
            id: "#{@id}_is_greather_than_or_equal"
          )}
          <label for={"#{@id}_is_greather_than_or_equal"}>&ge;</label>
        </div>
        <div class="flex items-center gap-2 mt-4">
          <.input
            type="number"
            min="0"
            max="100"
            name={@input_name}
            value={@percentage || 100}
            class="w-[75px] h-[27px] border border-slate-300 text-xs"
          />
          <span class="text-xs">&percnt;</span>
        </div>
        <div>
          <div class="w-full border border-gray-200 my-4"></div>
          <div class="flex flex-row items-center justify-end px-2 pb-2 gap-x-4">
            <button
              type="button"
              phx-click={
                JS.hide(to: "##{@id}_form")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
              class="text-center text-[#006CD9] text-xs font-semibold leading-none dark:text-white"
            >
              Cancel
            </button>
            <button
              phx-click={
                JS.hide(to: "##{@id}_form")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
              class="px-4 py-2 bg-[#0080FF] rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none"
            >
              Apply
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp progress_filter_text(nil, _progress_percentage), do: nil

  defp progress_filter_text(_selector, nil), do: nil

  defp progress_filter_text(selector, percentage) do
    selector_text =
      case selector do
        :is_equal_to -> " is ="
        :is_less_than_or_equal -> " is <="
        :is_greather_than_or_equal -> " is >="
        nil -> ""
      end

    selector_text <> " #{percentage}"
  end
end

defmodule OliWeb.Delivery.Content.Progress do
  use OliWeb, :html

  import OliWeb.Components.Delivery.Buttons, only: [instructor_dasboard_toggle_chevron: 1]

  attr(:progress_percentage, :string, default: "100")
  attr(:params_from_url, :map, default: %{})
  attr(:target, :any)

  attr(:progress_selector, :atom,
    values: [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal]
  )

  def render(assigns) do
    progress_selector = assigns.progress_selector || :is_less_than_or_equal
    assigns = assign(assigns, :progress_selector, progress_selector)

    ~H"""
    <div class="relative z-10">
      <div
        phx-click={
          JS.toggle(to: "#progress_form", display: "flex")
          |> JS.toggle(to: "#progress-down-icon")
          |> JS.toggle(to: "#progress-up-icon")
        }
        class="w-full h-9"
      >
        <button
          data-dropdown-toggle="dropdown"
          class={"h-full flex-shrink-0 rounded-md z-10 inline-flex items-center py-2.5 px-4 text-zinc-900 text-xs font-semibold leading-none dark:text-white border border-[#B0B0B0] #{if @progress_selector not in ["", nil], do: "!text-blue-500 text-xs font-semibold leading-none"}"}
          type="button"
        >
          Progress <%= progress_filter_text(
            @params_from_url,
            @progress_selector,
            @progress_percentage
          ) %>
          <div class="ml-3">
            <.instructor_dasboard_toggle_chevron id="progress" map_values={@progress_selector} />
          </div>
        </button>
      </div>
      <.form
        for={%{}}
        phx-click-away={
          JS.hide(to: "#progress_form")
          |> JS.hide(to: "#progress-up-icon")
          |> JS.show(to: "#progress-down-icon")
        }
        class="hidden bg-white dark:bg-gray-800 mt-1 rounded border flex flex-col p-2 absolute w-auto"
        phx-submit="apply_progress_filter"
        id="progress_form"
        phx-target={@target}
      >
        <div class="progress-options mt-2">
          <%= radio_button(:progress, :option, "is_equal_to",
            field: "is_equal_to",
            checked: @progress_selector == :is_equal_to,
            id: "is_equal_to"
          ) %>
          <label for="is_equal_to"><%= "is =" %></label>
          <%= radio_button(:progress, :option, "is_less_than_or_equal",
            field: "is_less_than_or_equal",
            checked: @progress_selector == :is_less_than_or_equal,
            id: "is_less_than_or_equal"
          ) %>
          <label for="is_less_than_or_equal"><%= "< =" %></label>
          <%= radio_button(:progress, :option, "is_greather_than_or_equal",
            field: "is_greather_than_or_equal",
            checked: @progress_selector == :is_greather_than_or_equal,
            id: "is_greather_than_or_equal"
          ) %>
          <label for="is_greather_than_or_equal"><%= "> =" %></label>
        </div>
        <div class="flex items-center gap-2 mt-4">
          <.input
            type="number"
            min="0"
            max="100"
            name="progress_percentage"
            value={@progress_percentage}
            class="w-[75px] h-[27px] border border-slate-300 text-xs"
          /> <span class="text-xs">&percnt;</span>
        </div>
        <div>
          <div class="w-full border border-gray-200 my-4"></div>
          <div class="flex flex-row items-center justify-end px-2 pb-2 gap-x-4">
            <button
              type="button"
              phx-click={
                JS.hide(to: "#progress_form")
                |> JS.hide(to: "#progress-up-icon")
                |> JS.show(to: "#progress-down-icon")
              }
              class="text-center text-neutral-600 text-xs font-semibold leading-none dark:text-white"
            >
              Cancel
            </button>
            <button
              phx-click={
                JS.hide(to: "#progress_form")
                |> JS.hide(to: "#progress-up-icon")
                |> JS.show(to: "#progress-down-icon")
              }
              class="px-4 py-2 bg-blue-500 rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none"
            >
              Apply
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp progress_filter_text(%{"progress_percentage" => _}, progress_selector, progress_percentage) do
    progress_selector_text =
      case progress_selector do
        :is_equal_to -> " is ="
        :is_less_than_or_equal -> " is <="
        :is_greather_than_or_equal -> " is >="
        nil -> ""
      end

    progress_selector_text <> " #{progress_percentage}"
  end

  defp progress_filter_text(_params_from_url, _progress_selector, _progress_percentage), do: ""
end

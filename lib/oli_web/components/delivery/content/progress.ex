defmodule OliWeb.Delivery.Content.Progress do
  use OliWeb, :html

  attr(:progress_percentage, :string, default: "100")

  attr(:progress_selector, :atom,
    default: :is_less_than_or_equal,
    values: [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal]
  )

  attr(:progress_filter_text, :string, default: "")
  attr(:target, :any)

  def render(assigns) do
    ~H"""
    <div class="relative z-10">
      <div
        phx-click={
          JS.toggle(to: "#progress_form", display: "flex")
          |> JS.dispatch("handle_arrow_direction")
        }
        class="w-full h-9"
      >
        <button
          id="dropdown-button"
          data-dropdown-toggle="dropdown"
          class="h-full flex-shrink-0 rounded-md z-10 inline-flex items-center py-2.5 px-4 text-xs text-center text-gray-900 bg-white border border-[#B0B0B0] focus:text-[#3B76D3] hover:border-[#3B76D3] hover:text-[#3B76D3] focus:outline-none focus:border-[#3B76D3] focus:ring-0 focus:border-radius-0"
          type="button"
        >
          Progress <%= progress_filter_text(
            @progress_filter_text,
            @progress_selector,
            @progress_percentage
          ) %>
          <svg
            class="w-2.5 h-2.5 ml-2.5"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 10 6"
          >
            <path
              id="path_arrow"
              stroke="currentColor"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M1 1L5 5L9 1"
            />
          </svg>
        </button>
      </div>
      <.form
        for={%{}}
        phx-click-away={JS.hide(to: "#progress_form") |> JS.dispatch("handle_arrow_direction")}
        class="hidden bg-white mt-2 rounded border flex flex-col p-2 gap-4 absolute w-[173px] h-[154px]"
        phx-submit="progress_filter"
        id="progress_form"
        phx-target={@target}
      >
        <div class="progress-options mt-2">
          <%= radio_button(:progress, :option, "is_equal_to",
            checked: if(@progress_selector == :is_equal_to, do: true, else: false),
            id: "is_equal_to"
          ) %>
          <label for="is_equal_to"><%= "is =" %></label>
          <%= radio_button(:progress, :option, "is_less_than_or_equal",
            checked: if(@progress_selector == :is_less_than_or_equal, do: true, else: false),
            id: "is_less_than_or_equal"
          ) %>
          <label for="is_less_than_or_equal"><%= "< =" %></label>
          <%= radio_button(:progress, :option, "is_greather_than_or_equal",
            checked: if(@progress_selector == :is_greather_than_or_equal, do: true, else: false),
            id: "is_greather_than_or_equal"
          ) %>
          <label for="is_greather_than_or_equal"><%= "> =" %></label>
        </div>
        <div class="flex items-center gap-2">
          <.input
            type="number"
            min="0"
            max="100"
            name="progress_percentage"
            value={@progress_percentage}
            class="w-[75px] h-[27px] border border-slate-300 text-xs"
          /> <span class="text-xs">&percnt;</span>
        </div>
        <div class="flex border-t border-gray-200 -mx-2 px-2 pt-3 pb-4 items-center justify-end gap-4">
          <button
            type="button"
            phx-click={
              JS.hide(to: "#progress_form")
              |> JS.dispatch("handle_arrow_direction")
            }
            class="flex items-center justify-center w-[58px] h-[28px] text-xs text-[#4F4F4F] hover:text-white bg-white hover:bg-[#3B76D3] rounded"
          >
            Cancel
          </button>
          <button
            phx-click={
              JS.hide(to: "#progress_form")
              |> JS.dispatch("handle_arrow_direction")
            }
            class="flex items-center justify-center w-[58px] h-[28px] text-xs text-[#4F4F4F] hover:text-white bg-white hover:bg-[#3B76D3] rounded"
          >
            Apply
          </button>
        </div>
      </.form>

      <script>
        window.addEventListener("handle_arrow_direction", e => {
          const path_arrow = document.getElementById("path_arrow")
          style = document.getElementById("progress_form").getAttribute("style")

          console.log(style);
          if (style === "display: none;" || style === null) {
            path_arrow.setAttribute('d', 'M1 5L5 1L9 5');
          } else {
            path_arrow.setAttribute('d', 'M1 1L5 5L9 1');
          }
        })
      </script>
    </div>
    """
  end

  defp progress_filter_text("", _progress_selector, _progress_percentage), do: ""

  defp progress_filter_text(_progress_filter_text, progress_selector, progress_percentage) do
    progress_selector_text =
      case progress_selector do
        :is_equal_to -> " is ="
        :is_less_than_or_equal -> " is <="
        :is_greather_than_or_equal -> " is >="
        nil -> ""
      end

    progress_selector_text <> " #{progress_percentage}"
  end
end

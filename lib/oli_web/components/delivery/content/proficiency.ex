defmodule OliWeb.Delivery.Content.Proficiency do
  use OliWeb, :html

  attr :options, :list,
    default: [
      %{id: 1, name: "Low"},
      %{id: 2, name: "Medium"},
      %{id: 3, name: "High"}
    ]

  attr :target, :map, default: %{}
  attr :selected_proficiency_ids, :list, default: []
  attr :params_from_url, :map

  def render(assigns) do
    ~H"""
    <div class="relative z-10">
      <div
        phx-click={
          JS.toggle(to: "#proficiency_form", display: "flex")
          |> JS.dispatch("handle_proficiency_arrow_direction")
        }
        class="w-full h-9"
      >
        <button
          data-dropdown-toggle="dropdown"
          class="h-full flex-shrink-0 rounded-md z-10 inline-flex items-center py-2.5 px-4 text-xs text-center text-gray-900 bg-white border border-[#B0B0B0] focus:text-[#3B76D3] hover:border-[#3B76D3] hover:text-[#3B76D3] focus:outline-none focus:border-[#3B76D3] focus:ring-0 focus:border-radius-0"
          type="button"
        >
          Proficiency <%= show_proficiency_selected_values(
            @params_from_url,
            @selected_proficiency_ids
          ) %>
          <svg
            class="w-2.5 h-2.5 ml-2.5"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 10 6"
          >
            <path
              id="proficiency_path_arrow"
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
        phx-click-away={
          JS.hide(to: "#proficiency_form") |> JS.dispatch("handle_proficiency_arrow_direction")
        }
        class="hidden bg-white mt-2 rounded border flex flex-col p-2 gap-4 absolute w-[173px] h-[154px]"
        phx-submit="apply_proficiency_filter"
        id="proficiency_form"
        phx-target={@target}
      >
        <.input
          :for={option <- @options}
          name={option.id}
          value={option.id}
          label={option.name}
          checked={option.id in @selected_proficiency_ids}
          type="checkbox"
          class_label="text-zinc-900 text-xs font-normal leading-none dark:text-white"
        />
        <div class="flex border-t border-gray-200 -mx-2 px-2 pt-3 pb-4 items-center justify-end gap-4">
          <button
            type="button"
            phx-click={
              JS.hide(to: "#proficiency_form")
              |> JS.dispatch("handle_proficiency_arrow_direction")
            }
            class="flex items-center justify-center w-[58px] h-[28px] text-xs text-[#4F4F4F] hover:text-white bg-white hover:bg-[#3B76D3] rounded"
          >
            Cancel
          </button>
          <button
            phx-click={
              JS.hide(to: "#proficiency_form")
              |> JS.dispatch("handle_proficiency_arrow_direction")
            }
            class="flex items-center justify-center w-[58px] h-[28px] text-xs text-[#4F4F4F] hover:text-white bg-white hover:bg-[#3B76D3] rounded"
          >
            Apply
          </button>
        </div>
      </.form>

      <script>
        window.addEventListener("handle_proficiency_arrow_direction", e => {
          const proficiency_path_arrow = document.getElementById("proficiency_path_arrow")
          style = document.getElementById("proficiency_form").getAttribute("style")

          console.log(style);
          if (style === "display: none;" || style === null) {
            proficiency_path_arrow.setAttribute('d', 'M1 5L5 1L9 5');
          } else {
            proficiency_path_arrow.setAttribute('d', 'M1 1L5 5L9 1');
          }
        })
      </script>
    </div>
    """
  end

  defp show_proficiency_selected_values(
         %{"selected_proficiency_ids" => _selected_proficiency_ids},
         values
       ) do
    starting_string =
      case values do
        map when map == [] -> ""
        _ -> "is "
      end

    starting_string <>
      Enum.map_join(values, ", ", fn value ->
        case value do
          1 -> "Low"
          2 -> "Medium"
          3 -> "High"
        end
      end)
  end

  defp show_proficiency_selected_values(_params_from_url, _values), do: ""
end

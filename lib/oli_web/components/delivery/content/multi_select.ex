defmodule OliWeb.Delivery.Content.MultiSelect do
  use OliWeb, :html

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]
  alias Phoenix.LiveView.JS

  attr :placeholder, :string, default: "Select an option"
  attr :disabled, :boolean, default: false
  attr :options, :list, default: []
  attr :id, :string
  attr :target, :map, default: %{}
  attr :selected_values, :map, default: %{}
  attr :selected_proficiency_ids, :list, default: []

  def render(assigns) do
    ~H"""
    <div class={"flex flex-col relative rounded outline outline-1 h-9 #{if @selected_values != %{}, do: "outline-[#006CD9] dark:outline-[#4CA6FF]", else: "outline outline-1 outline-[#ced1d9] dark:outline-[#3B3740]"}"}>
      <div
        phx-click={
          if(!@disabled,
            do:
              JS.toggle(to: "##{@id}-options-container")
              |> JS.toggle(to: "##{@id}-down-icon")
              |> JS.toggle(to: "##{@id}-up-icon")
          )
        }
        class={[
          "flex gap-x-2 px-2 h-9 justify-between items-center w-auto hover:cursor-pointer rounded",
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap">
          <span
            :if={@selected_values == %{}}
            class="text-[#353740] text-xs font-semibold leading-none dark:text-[#EEEBF5]"
          >
            {@placeholder}
          </span>
          <span
            :if={@selected_values != %{}}
            class="text-[#006CD9] dark:text-[#4CA6FF] text-xs font-semibold leading-none"
          >
            Proficiency is {show_proficiency_selected_values(@selected_values)}
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="relative">
        <div
          class="py-4 px-4 hidden z-50 absolute dark:bg-gray-800 bg-white w-48 border overflow-y-scroll top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div>
            <.form
              :let={_f}
              class="flex flex-column gap-y-3"
              for={%{}}
              as={:options}
              phx-change="toggle_selected"
              phx-target={@target}
            >
              <.input
                :for={option <- @options}
                name={option.id}
                value={option.selected}
                label={option.name}
                checked={option.id in @selected_proficiency_ids}
                type="checkbox"
                label_class="text-zinc-900 text-xs font-normal leading-none dark:text-white"
              />
            </.form>
          </div>
          <div class="w-full border border-gray-200 my-4"></div>
          <div class="flex flex-row items-center justify-end px-4 gap-x-4">
            <button
              class="text-center text-[#006CD9] text-xs font-semibold leading-none dark:text-white"
              phx-click={
                JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
            >
              Cancel
            </button>
            <button
              class="px-4 py-2 bg-[#0080FF] rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none"
              phx-click={
                JS.push("apply_proficiency_filter")
                |> JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
              phx-target={@target}
              phx-value={@selected_proficiency_ids}
              disabled={@disabled}
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_proficiency_selected_values(values) do
    Enum.map_join(values, ", ", fn {_id, values} -> values end)
  end
end

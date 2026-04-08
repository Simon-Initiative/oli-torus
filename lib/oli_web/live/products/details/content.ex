defmodule OliWeb.Products.Details.Content do
  use OliWeb, :html
  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias Phoenix.LiveView.JS

  attr(:product, :any, required: true)
  attr(:updates, :any, required: true)
  attr(:changeset, :any, default: nil)
  attr(:save, :any, required: true)
  attr(:source_materials_url, :string, default: nil)
  attr(:customize_url, :string, required: true)
  attr(:edit_url, :string, default: nil)
  attr(:schedule_url, :string, default: nil)
  attr(:unnumbered_unit_options, :list, default: [])

  def render(assigns) do
    ~H"""
    <% updates_count = Enum.count(@updates) %>
    <% selected_units =
      @unnumbered_unit_options
      |> Enum.filter(&(&1.resource_id in List.wrap(@changeset[:unnumbered_unit_ids].value)))
      |> Enum.map(&{&1.resource_id, &1.title})
      |> Map.new() %>
    <% selected_unit_ids = Map.keys(selected_units) %>
    <div>
      <div class="flex flex-col gap-3">
        <h5 class="font-semibold text-[18px] leading-[24px] m-0">Updates</h5>
        <div class="flex flex-col gap-[6px]">
          <p :if={updates_count == 0} class="text-[16px] leading-[24px] m-0">
            There are <b>no updates</b> available for this template.
          </p>
          <div :if={updates_count > 0} class="flex items-center gap-[6px]">
            <p class="text-[16px] leading-[24px] m-0">
              {ngettext(
                "There is <b>one available update</b> for this template",
                "There are <b>%{count} available updates</b> for this template",
                updates_count
              )
              |> raw()}
            </p>
            <span
              id="manage-source-materials-updates-badge"
              class="inline-flex items-center rounded-full bg-Fill-Buttons-fill-primary px-[6px] py-[4px] text-[12px] font-semibold leading-[12px] text-Text-text-white"
            >
              {ngettext("1 update", "%{count} updates", updates_count)}
            </span>
          </div>
          <.action_link
            :if={updates_count > 0 and @source_materials_url}
            navigate={@source_materials_url}
            label="Manage source materials"
          />
          <.action_link
            navigate={@customize_url}
            label="Customize content"
          />
          <.action_link
            :if={@edit_url}
            navigate={@edit_url}
            label="Edit template details"
          />
          <.action_link
            :if={@schedule_url}
            navigate={@schedule_url}
            label="Edit scheduling and assessment settings"
          />
        </div>
      </div>

      <.form for={@changeset} phx-change={@save}>
        <div class="flex flex-col gap-[6px] mt-3">
          <.input
            type="checkbox"
            field={@changeset[:apply_major_updates]}
            label="Apply major updates to course sections"
            aria-describedby="apply-major-updates-desc"
          />
          <p id="apply-major-updates-desc" class="text-[14px] leading-[24px] text-Text-text-low m-0">
            Allow major project publications to be applied to course sections created from this template
          </p>
        </div>

        <div class="flex flex-col gap-[6px] mt-4">
          <h5 class="font-semibold text-[18px] leading-[24px] m-0">Presentation</h5>
          <.input
            type="checkbox"
            field={@changeset[:display_curriculum_item_numbering]}
            label="Display curriculum item numbers"
            aria-describedby="display-curriculum-numbering-desc"
          />
          <p
            id="display-curriculum-numbering-desc"
            class="text-[14px] leading-[24px] text-Text-text-low m-0"
          >
            Enable students to see the curriculum's module and unit numbers
          </p>
          <div class="flex flex-col gap-[6px]">
            <label
              for="section_unnumbered_unit_ids"
              class="block text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100"
            >
              Exclude the following units
            </label>
            <.unnumbered_units_multi_select
              id="section_unnumbered_unit_ids"
              options={@unnumbered_unit_options}
              selected_values={selected_units}
              selected_resource_ids={selected_unit_ids}
              disabled={!@product.display_curriculum_item_numbering}
            />
          </div>
          <p id="unnumbered-units-desc" class="text-[14px] leading-[24px] text-Text-text-low m-0">
            Selected units and their child content will not display curriculum item numbers.
          </p>
        </div>
      </.form>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :disabled, :boolean, default: false
  attr :options, :list, required: true
  attr :selected_values, :map, required: true
  attr :selected_resource_ids, :list, required: true

  defp unnumbered_units_multi_select(assigns) do
    ~H"""
    <div class="flex flex-col w-full">
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
          "flex gap-x-4 px-4 justify-between items-center w-full min-h-[44px] border border-[#D4D4D4] rounded bg-white dark:bg-gray-800 hover:cursor-pointer",
          if(@disabled,
            do:
              "bg-gray-100 text-gray-500 hover:cursor-not-allowed dark:bg-gray-800 dark:text-gray-400"
          )
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap py-2">
          <span
            :if={@selected_values == %{}}
            class="px-1 text-[#383a44] text-base font-medium leading-none dark:text-white"
          >
            None
          </span>
          <span :if={@selected_values != %{}}>
            <.show_selected_units selected_values={@selected_values} />
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="w-full relative">
        <div
          class="w-full max-h-60 py-4 hidden z-50 absolute dark:bg-gray-800 bg-white border overflow-y-scroll top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div :if={@options == []} class="px-4 text-sm leading-6 text-Text-text-low">
            No top-level units are available for selection.
          </div>
          <div :if={@options != []} class="flex flex-column gap-y-3 px-4">
            <input
              type="hidden"
              name="section[unnumbered_unit_ids][]"
              value=""
              disabled={@disabled}
            />
            <label
              :for={option <- @options}
              class={[
                "flex items-center gap-2 text-xs font-normal leading-none text-zinc-900 dark:text-white",
                if(@disabled, do: "cursor-not-allowed opacity-70", else: "cursor-pointer")
              ]}
            >
              <input
                type="checkbox"
                name="section[unnumbered_unit_ids][]"
                value={option.resource_id}
                checked={option.resource_id in @selected_resource_ids}
                disabled={@disabled}
                class="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
              />
              <span>{option.title}</span>
            </label>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :selected_values, :map, required: true

  defp show_selected_units(assigns) do
    ~H"""
    <div
      :for={{_id, title} <- @selected_values}
      class="text-white inline-flex items-center text-xs font-medium bg-[#0165da] border rounded-full px-2 py-0.5 m-0.5"
    >
      <span>{title}</span>
    </div>
    """
  end
end

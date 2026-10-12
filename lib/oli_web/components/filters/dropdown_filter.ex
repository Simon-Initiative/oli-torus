defmodule OliWeb.Components.Filters.DropdownFilter do
  @moduledoc """
  Stateless pieces of a dropdown filter: `trigger/1`, `panel/1`, `search/1` and
  `checkbox_options/1`. Every element id derives from the filter's `id`, so a page can hold several
  filters. `OliWeb.Components.Filters.CheckboxFilter` composes them.
  """

  use Phoenix.Component

  alias OliWeb.Icons

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :open, :boolean, default: false
  attr :selected_count, :integer, default: 0
  attr :rest, :global

  @doc "The button that opens and closes the panel; it counts the applied values."
  def trigger(assigns) do
    ~H"""
    <button
      id={"#{@id}-trigger"}
      type="button"
      aria-expanded={to_string(@open)}
      aria-controls={"#{@id}-panel"}
      data-active={@selected_count > 0 && "true"}
      class={[
        "inline-flex h-9 items-center gap-2 rounded-md border bg-Surface-surface-primary px-3 text-sm font-semibold transition",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        if(@selected_count > 0 or @open,
          do: "border-Fill-Buttons-fill-primary text-Text-text-button",
          else: "border-Border-border-default text-Text-text-high hover:border-Border-border-hover"
        )
      ]}
      {@rest}
    >
      {@label}
      <span
        :if={@selected_count > 0}
        data-count
        class="rounded-full bg-Fill-Buttons-fill-primary-bold px-2 text-xs leading-5 text-Text-text-white"
      >
        {@selected_count}<span class="sr-only"> selected</span>
      </span>
      <Icons.chevron_down
        width="16"
        height="16"
        class={["fill-current transition-transform", @open && "rotate-180"]}
      />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :open, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "The box under the trigger that holds the filter's controls; hidden while closed."
  def panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-panel"}
      hidden={!@open}
      phx-hook="KeepInViewport"
      class="absolute left-0 top-full z-50 mt-1 w-72 rounded-md border border-Border-border-default bg-Surface-surface-primary p-4 shadow-lg"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""

  @doc "A labelled search box; its value is sent as `query`."
  def search(assigns) do
    ~H"""
    <div class="relative mb-3">
      <label for={"#{@id}-search"} class="sr-only">{@label}</label>
      <span class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2">
        <Icons.search />
      </span>
      <input
        id={"#{@id}-search"}
        type="text"
        name="query"
        value={@value}
        placeholder="Search"
        autocomplete="off"
        phx-debounce="300"
        class="h-9 w-full rounded-md border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input pl-9 pr-3 text-sm text-Text-text-high placeholder:text-Text-text-low focus:outline focus:outline-2 focus:outline-Fill-Buttons-fill-primary"
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :legend, :string, required: true
  attr :options, :list, required: true, doc: "Maps with `:id` and `:label`."
  attr :checked, :list, default: [], doc: "Ids of the checked options."
  attr :visible, :list, default: nil, doc: "Ids of the options shown; `nil` shows them all."

  attr :revision, :integer,
    default: 0,
    doc: "A new value renders every checkbox again, so the browser state returns to `checked`."

  @doc """
  One checkbox per option, sent as `selected[]`. Options outside `visible` are hidden, not
  removed, so a checked one keeps its value in the form.
  """
  def checkbox_options(assigns) do
    visible = assigns.visible && MapSet.new(assigns.visible)
    checked = MapSet.new(assigns.checked)

    rows =
      Enum.map(assigns.options, fn option ->
        %{
          option: option,
          visible: is_nil(visible) or MapSet.member?(visible, option.id),
          checked: MapSet.member?(checked, option.id)
        }
      end)

    assigns = assign(assigns, rows: rows, shown: Enum.count(rows, & &1.visible))

    ~H"""
    <fieldset>
      <legend class="sr-only">{@legend}</legend>
      <p aria-live="polite" class="sr-only">{options_count(@shown)}</p>
      <div class="flex max-h-60 flex-col gap-1 overflow-y-auto">
        <div
          :for={%{option: option} = row <- @rows}
          id={"#{@id}-option-#{option.id}"}
          hidden={!row.visible}
          class={[
            if(row.visible, do: "flex", else: "hidden"),
            "items-center gap-2 rounded px-1 py-1 hover:bg-Fill-fill-hover"
          ]}
        >
          <input
            id={"#{@id}-option-#{option.id}-input"}
            type="checkbox"
            name="selected[]"
            value={to_string(option.id)}
            checked={row.checked}
            data-revision={@revision}
            class="h-4 w-4 rounded border-Border-border-active"
          />
          <label for={"#{@id}-option-#{option.id}-input"} class="text-sm text-Text-text-high">
            {option.label}
          </label>
        </div>
      </div>
      <p :if={@shown == 0} class="py-2 text-sm text-Text-text-low">No results found</p>
    </fieldset>
    """
  end

  defp options_count(1), do: "1 option"
  defp options_count(count), do: "#{count} options"
end

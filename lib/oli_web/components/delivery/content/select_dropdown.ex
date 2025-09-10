defmodule OliWeb.Delivery.Content.SelectDropdown do
  use OliWeb, :html

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :phx_change, :string, required: true
  attr :disabled, :boolean, default: false
  attr :target, :any, default: nil
  attr :selected_value, :string, default: nil
  attr :options, :list, required: true

  def render(assigns) do
    assigns =
      assign(assigns,
        effective_value:
          assigns.selected_value ||
            (List.first(assigns.options) && List.first(assigns.options).value)
      )

    ~H"""
    <div class={"flex flex-col relative rounded outline outline-1 h-9 #{outline_class(@effective_value)}"}>
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
          <span class="text-Text-text-button text-base font-semibold leading-none">
            {selected_option_label(@effective_value, @options)}
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={%{@effective_value => ""}} />
      </div>

      <div class="relative">
        <div
          class="py-2 px-2 hidden z-50 absolute dark:bg-gray-800 bg-white w-48 border overflow-y-auto top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <.form
            for={%{}}
            phx-change={@phx_change}
            phx-target={@target}
          >
            <div class="flex flex-col gap-2">
              <select name={@name} class="hidden" />
              <button
                :for={opt <- @options}
                type="button"
                name={@name}
                value={opt.value}
                class="flex flex-row justify-between text-left text-sm text-Text-text-high bg-Specially-Tokens-Fill-fill-input hover:bg-Fill-fill-hover px-2 py-1 rounded"
                phx-click={
                  JS.push(@phx_change)
                  |> JS.hide(to: "##{@id}-options-container")
                  |> JS.hide(to: "##{@id}-up-icon")
                  |> JS.show(to: "##{@id}-down-icon")
                }
                phx-target={@target}
                phx-value-filter={opt.value}
              >
                <span class={" #{if opt.value == @selected_value, do: "text-Text-text-high", else: "text-Text-text-low"}"}>
                  {opt.label}
                </span>
                <%= if opt.value == @selected_value do %>
                  <Icons.check stroke_class="stroke-Icon-icon-active" />
                <% end %>
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp outline_class(nil), do: "outline-Border-border-default"
  defp outline_class(_selected), do: "outline-Text-text-button"

  defp selected_option_label(selected, options) do
    selected_str = to_string(selected)

    options
    |> Enum.find(fn o -> to_string(o.value) == selected_str end)
    |> case do
      %{label: label} -> label
      _ -> selected_str
    end
  end
end

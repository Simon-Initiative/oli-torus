defmodule OliWeb.Components.Delivery.Buttons do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Icons

  attr(:type, :string, default: "button")
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button type={@type} class={["torus-button primary", @class]} disabled={@disabled}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:type, :string, default: "button")
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: nil)
  attr(:id, :string, required: true)
  attr(:options, :list, required: true)
  attr(:onclick, :string, default: nil)
  attr(:href, :string, default: nil)
  attr(:target, :string, default: nil)
  slot(:inner_block)

  def button_with_options(assigns) do
    assigns =
      assigns
      |> assign(:button_class, "torus-button primary !rounded-r-none")
      |> assign(
        :dropdown_button_class,
        "flex justify-center rounded-r-sm items-center px-2 text-white bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-600 border-l border-delivery-primary-600 hover:bg-delivery-primary-700"
      )
      |> assign(
        :option_class,
        "text-gray-600 dark:text-white block whitespace-nowrap px-4 py-2 text-sm w-full text-left hover:bg-gray-100 dark:hover:bg-gray-800"
      )

    ~H"""
    <div class="relative inline-block text-left">
      <div class="flex">
        <%= if assigns[:href] do %>
          <a
            href={@href}
            {(if @target do [target: @target] else [] end)}
            class={[@button_class, @class]}
            disabled={@disabled}
          >
            <%= render_slot(@inner_block) %>
          </a>
        <% else %>
          <button
            phx-target={assigns[:onclick_target]}
            phx-click={assigns[:onclick]}
            id={"#{@id}_button"}
            type={@type}
            class={[@button_class, @class]}
            disabled={@disabled}
          >
            <%= render_slot(@inner_block) %>
          </button>
        <% end %>
        <button type="button" phx-click={toggle_options(@id)} class={@dropdown_button_class}>
          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>
      <div
        phx-click-away={toggle_options(@id)}
        id={"#{@id}_options"}
        class="hidden absolute w-40 right-0 z-10 mt-2 origin-top-right divide-y divide-gray-100 rounded-md bg-white dark:bg-black dark:text shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none"
        role="menu"
        aria-orientation="vertical"
        aria-labelledby="menu-button"
        tabindex="-1"
      >
        <div class="py-1" role="none">
          <%= for {option, index} <- Enum.with_index(@options) do %>
            <%= if option[:href] do %>
              <a
                href={option.href}
                {(if option[:target] do [target: option.target] else [] end)}
                class={@option_class}
                role="menuitem"
                tabindex="-1"
                id={"menu-item-#{@id}-#{index}"}
              >
                <%= option.text %>
                <%= if option[:target] == "_blank" do %>
                  <i class="fa-solid fa-arrow-up-right-from-square ml-2"></i>
                <% end %>
              </a>
            <% else %>
              <button
                type="button"
                phx-click={toggle_options(option.on_click, @id)}
                class={@option_class}
                role="menuitem"
                tabindex="-1"
                id={"menu-item-#{@id}-#{index}"}
              >
                <%= option.text %>
              </button>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp toggle_options(js \\ %JS{}, target_id) do
    js
    |> JS.toggle(to: "##{target_id}_options")
  end

  @spec help_button(any()) :: Phoenix.LiveView.Rendered.t()
  def help_button(assigns) do
    ~H"""
    <!-- Button trigger modal -->
    <button
      type="button"
      class="btn btn-light btn-sm inline-flex items-center"
      onclick="window.showHelpModal();"
    >
      <span class="hidden sm:inline">Tech Support</span>
      <span class="inline sm:hidden"><i class="fa-solid fa-circle-question"></i></span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :map_values, :map, default: %{}

  def instructor_dasboard_toggle_chevron(assigns) do
    ~H"""
    <div>
      <div id={"#{@id}-down-icon"}>
        <Icons.chevron_down class={"dark:fill-white " <> if @map_values != %{}, do: "fill-blue-400 dark:fill-blue-400", else: ""} />
      </div>
      <div class="hidden" id={"#{@id}-up-icon"}>
        <Icons.chevron_down class={"rotate-180 dark:fill-white " <> if(@map_values != %{}, do: "fill-blue-400 dark:fill-blue-400", else: "")} />
      </div>
    </div>
    """
  end
end

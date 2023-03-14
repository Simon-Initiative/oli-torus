defmodule OliWeb.Components.Delivery.Buttons do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias OliWeb.Router.Helpers, as: Routes

  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil

  def button(assigns) do
    ~H"""
    <button type={@type} class={["torus-button primary", @class]} disabled={@disabled}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :id, :string, required: true
  attr :options, :list, required: true

  def button_with_options(assigns) do
    ~H"""
    <div class="relative inline-block text-left">
      <div class="flex">
        <button id={"#{@id}_button"} type={@type} class={["torus-button primary !rounded-r-none", @class]} disabled={@disabled}>
          <%= render_slot(@inner_block) %>
        </button>
        <button type="button" phx-click={toggle_options(@id)} class="flex justify-center rounded-r-sm items-center px-2 text-white bg-delivery-primary-600 hover:bg-delivery-primary-700">
          <svg  class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
      <div phx-click-away={toggle_options(@id)} id={"#{@id}_options"} class="hidden absolute w-40 right-0 z-10 mt-2 origin-top-right divide-y divide-gray-100 rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none" role="menu" aria-orientation="vertical" aria-labelledby="menu-button" tabindex="-1">
        <div class="py-1" role="none">
          <%= for {option, index} <- Enum.with_index(@options) do %>
            <button type="button" phx-click={toggle_options(option.on_click, @id)} class="text-gray-600 block px-4 py-2 text-sm w-full text-left hover:bg-gray-100" role="menuitem" tabindex="-1" id={"menu-item-#{@id}-#{index}"}><%= option.text %></button>
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

  def help_button(assigns) do
    ~H"""
    <!-- Button trigger modal -->
    <button type="button" class="btn btn-xs btn-light inline-flex items-center help-btn m-1" data-bs-toggle="modal" data-bs-target="#help-modal">
      <img src={Routes.static_path(OliWeb.Endpoint, "/images/icons/life-ring-regular.svg")} class="help-icon mr-1" />
      <span>Help</span>
    </button>
    """
  end
end

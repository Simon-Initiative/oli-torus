defmodule OliWeb.Components.Delivery.ExplorationCard do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  attr :dark, :boolean, default: false
  attr :exploration, :map
  attr :section_slug, :string

  def render(assigns) do
    ~H"""
      <div class={"@container/card flex-1 bg-white dark:bg-gray-800 dark:text-white shadow #{if @dark, do: "bg-delivery-header-800 text-white"}"}>
        <div class="p-6 flex flex-col">
          <div class="flex flex-col @2xl/card:flex-row @2xl/card:items-center @2xl/card:justify-between">
            <h6 class="font-semibold text-lg leading-6"><%= @exploration.title %></h6>
            <div class="flex w-full gap-3 justify-end">
              <a
                href={Routes.page_delivery_path(OliWeb.Endpoint, :page, @section_slug, @exploration.slug)}
                class="btn text-white hover:text-white inline-flex bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700">Open</a>
            </div>
          </div>
        </div>
      </div>
    """
  end
end

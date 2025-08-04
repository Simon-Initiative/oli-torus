defmodule OliWeb.Components.Delivery.ExplorationCard do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  attr :dark, :boolean, default: false
  attr :exploration, :map
  attr :section_slug, :string
  attr :preview_mode, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class={"@container/card flex-1 bg-white dark:bg-gray-800 dark:text-white shadow #{if @dark, do: "bg-delivery-instructor-dashboard-header-800 text-white"}"}>
      <div class="p-6 flex flex-col">
        <div class="flex flex-col @2xl/card:flex-row @2xl/card:items-center @2xl/card:justify-between">
          <h6 class="font-semibold text-lg leading-6">{@exploration.title}</h6>
          <div class="flex w-full gap-3 justify-end">
            <a
              href={
                Routes.page_delivery_path(
                  OliWeb.Endpoint,
                  if(@preview_mode, do: :page_preview, else: :page),
                  @section_slug,
                  @exploration.slug
                )
              }
              class="btn text-white hover:text-white inline-flex bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700"
            >
              Open
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

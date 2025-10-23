defmodule OliWeb.Components.Delivery.CourseLatestVisitedPage do
  use OliWeb, :html

  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils

  attr :page_revision, Oli.Resources.Revision
  attr :section_slug, :string
  attr :is_instructor, :boolean
  attr :preview_mode, :boolean
  attr :ctx, :map
  attr :scheduled_dates, :list

  def latest_visited_page(assigns) do
    ~H"""
    <div id="latest_visited_page_card" class="bg-white dark:bg-gray-800 shadow">
      <div class="p-4">
        Continue where you left off
      </div>
      <div class="p-4 border-t border-gray-100 dark:border-gray-700">
        <section class="flex flex-row justify-between items-center w-full">
          <h4 class="text-sm font-bold tracking-wide text-gray-800 dark:text-white">
            {@page_revision.title}
          </h4>

          <%= if !@is_instructor do %>
            <span class="w-64 h-10 text-sm tracking-wide text-gray-800 dark:text-white bg-gray-100 dark:bg-gray-500 rounded-sm flex justify-center items-center ml-auto mr-3">
              {DeliveryUtils.get_resource_scheduled_date(
                @page_revision.resource_id,
                @scheduled_dates,
                @ctx
              )}
            </span>
            <.link
              navigate={~p"/sections/#{@section_slug}/page/#{@page_revision.slug}"}
              class="torus-button primary h-10"
            >
              Open
            </.link>
          <% else %>
            <Buttons.button_with_options
              id="open-latest-visited-page-button"
              href={~p"/sections/#{@section_slug}/preview/page/#{@page_revision.slug}"}
              target="_blank"
              options={[
                %{
                  text: "Open as student",
                  href: ~p"/sections/#{@section_slug}/page/#{@page_revision.slug}",
                  target: "_blank"
                }
              ]}
            >
              Open as instructor
            </Buttons.button_with_options>
          <% end %>
        </section>
      </div>
    </div>
    """
  end
end

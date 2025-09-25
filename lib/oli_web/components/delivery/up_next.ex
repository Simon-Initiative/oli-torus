defmodule OliWeb.Components.Delivery.UpNext do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes

  attr(:user, :any, required: true)
  attr(:next_activities, :list, required: true)
  attr(:section_slug, :string, required: true)

  def up_next(assigns) do
    ~H"""
    <div class="bg-delivery-instructor-dashboard-header text-white border-b border-slate-300">
      <div class="container mx-auto flex flex-col justify-between">
        <h4 class="leading-loose px-8 py-4">
          Up Next for <span class="font-bold">{user_name(@user)}</span>
        </h4>

        <div class="flex flex-col md:flex-row md:px-8 md:pb-4">
          <%= for activity <- @next_activities do %>
            <.card
              badge_name={if activity.graded, do: "Graded Assignment", else: "Course Content"}
              badge_bg_color={if activity.graded, do: "bg-fuchsia-800", else: "bg-green-700"}
              title={activity.title}
              percent_complete={activity.progress}
              complete_by_date={activity.end_date}
              scheduling_type={activity.scheduling_type}
              open_href={
                Routes.page_delivery_path(OliWeb.Endpoint, :page, @section_slug, activity.slug)
              }
              percent_students_completed={Float.floor(activity.completion_percentage) |> trunc()}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr(:badge_name, :string, required: true)
  attr(:badge_bg_color, :string, required: true)
  attr(:title, :string, required: true)
  attr(:percent_complete, :integer, required: true)
  attr(:complete_by_date, :string, required: true)
  attr(:open_href, :string, required: true)
  attr(:percent_students_completed, :integer, required: true)
  attr(:request_extension_href, :string)
  attr(:scheduling_type, :string)

  def card(assigns) do
    ~H"""
    <div class="flex-1 rounded p-8 py-4 mb-2 last:mb-0 md:last:mb-2 md:mr-2 bg-delivery-instructor-dashboard-header-800">
      <div class="flex my-2">
        <span class={"rounded-full py-1 px-6 #{@badge_bg_color} text-white"}>
          {@badge_name}
        </span>
      </div>
      <div class="my-2">
        <span class="font-bold">{@title}</span>
      </div>
      <.progress_bar width="200px" percent={@percent_complete} />
      <div class="my-2 flex flex-row">
        <div class="flex-1 bg-delivery-instructor-dashboard-header-700 rounded p-2 text-center">
          {@scheduling_type} {@complete_by_date}
        </div>
        <div class="text-white">
          <a
            href={@open_href}
            class="btn text-white hover:text-white inline-flex ml-2 bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700"
          >
            Open
          </a>
        </div>
      </div>
      <%= if assigns[:request_extension_href] do %>
        <div class="my-2">
          <a href={@request_extension_href} class="text-current hover:text-current underline">
            Request Extension
          </a>
        </div>
      <% end %>
      <%= if assigns[:percent_students_completed] do %>
        <div class="my-2">
          <span class="italic text-sm">
            {@percent_students_completed}% of students have completed this content
          </span>
        </div>
      <% end %>
    </div>
    """
  end
end

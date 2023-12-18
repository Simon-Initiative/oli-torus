defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.Schedule

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]

    schedule_for_current_week = Sections.get_schedule_for_current_week(section)

    {:ok,
     assign(socket,
       active_tab: :index,
       schedule_for_current_week: schedule_for_current_week
     )}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-index">
      <h1 class="text-6xl mb-8">Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span></h1>
    </.hero_banner>

    <div class="container mx-auto">
      <div class="my-8 px-16">
        <div class="font-bold text-2xl mb-4">Up Next</div>

        <%= case @schedule_for_current_week do %>
          <% {week, schedule_ranges} -> %>
            <Schedule.week ctx={@ctx} week_number={week} schedule_ranges={schedule_ranges} />
          <% _ -> %>
            <div class="text-xl">No schedule for this week.</div>
        <% end %>
      </div>
    </div>
    """
  end
end

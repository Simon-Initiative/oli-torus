defmodule OliWeb.Delivery.Student.IndexLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.Schedule
  alias Oli.Delivery.Attempts

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]
    current_user_id = socket.assigns[:current_user].id

    schedule_for_current_week =
      Sections.get_schedule_for_current_week(section, current_user_id)

    {:ok,
     assign(socket,
       active_tab: :index,
       schedule_for_current_week: schedule_for_current_week,
       section_slug: section.slug,
       historical_graded_attempt_summary: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-index">
      <h1 class="text-4xl md:text-6xl mb-8">
        Hi, <span class="font-bold"><%= user_given_name(@ctx) %></span>
      </h1>
    </.hero_banner>

    <div class="overflow-x-scroll md:overflow-x-auto container mx-auto">
      <div class="my-8 px-16">
        <div class="font-bold text-2xl mb-4">Up Next</div>

        <%= case @schedule_for_current_week do %>
          <% {week, schedule_ranges} -> %>
            <Schedule.week
              ctx={@ctx}
              week_number={week}
              show_border={false}
              schedule_ranges={schedule_ranges}
              section_slug={@section_slug}
              historical_graded_attempt_summary={@historical_graded_attempt_summary}
              request_path={~p"/sections/#{@section_slug}"}
            />
          <% _ -> %>
            <div class="text-xl">No schedule for this week.</div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event(
        "load_historical_graded_attempt_summary",
        %{"page_revision_slug" => page_revision_slug},
        socket
      ) do
    %{section: section, current_user: current_user} = socket.assigns

    historical_graded_attempt_summary =
      Attempts.get_historical_graded_attempt_summary(section, page_revision_slug, current_user.id)

    {:noreply,
     assign(socket, historical_graded_attempt_summary: historical_graded_attempt_summary)}
  end

  def handle_event("clear_historical_graded_attempt_summary", _params, socket) do
    {:noreply, assign(socket, historical_graded_attempt_summary: nil)}
  end
end

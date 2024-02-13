defmodule OliWeb.Delivery.Student.ScheduleLive do
  use OliWeb, :live_view

  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.{Schedule, Utils}
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.{HistoricalGradedAttemptSummary}

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]
    current_user_id = socket.assigns[:current_user].id

    schedule = Sections.get_ordered_schedule(section, current_user_id)

    current_datetime = DateTime.utc_now()
    current_week = Utils.week_number(section.start_date, current_datetime)
    current_month = current_datetime.month

    if connected?(socket),
      do: async_scroll_to_current_week(self())

    {:ok,
     assign(socket,
       active_tab: :schedule,
       schedule: schedule,
       section_slug: section.slug,
       current_week: current_week,
       current_month: current_month,
       historical_graded_attempt_summary: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-schedule">
      <h1 class="text-6xl mb-8">Course Schedule</h1>
    </.hero_banner>

    <div id="schedule-view" class="container mx-auto" phx-hook="Scroller">
      <.schedule
        ctx={@ctx}
        schedule={@schedule}
        section_slug={@section_slug}
        current_week={@current_week}
        current_month={@current_month}
        historical_graded_attempt_summary={@historical_graded_attempt_summary}
      />
    </div>
    """
  end

  attr(:ctx, SessionContext, required: true)
  attr(:schedule, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:current_week, :integer, required: true)
  attr(:current_month, :integer, required: true)
  attr(:historical_graded_attempt_summary, HistoricalGradedAttemptSummary)

  def schedule(assigns) do
    ~H"""
    <div class="my-8 px-16">
      <div class="mb-8">
        Scroll though your course schedule to find all critical due dates and when assignments are due.
        Use this schedule view to see which activities you've completed throughout your time in the course.
      </div>

      <div class="flex flex-col">
        <%= for {{month, _year}, weekly_schedule} <- @schedule do %>
          <div class="flex flex-col md:flex-row">
            <div class={[
              "w-full md:w-32 uppercase font-bold border-b md:border-b-0 mb-3",
              if(month_active?(month, @current_month),
                do: "text-gray-500 border-gray-500",
                else: "text-gray-300 dark:text-gray-700 border-gray-300 dark:border-gray-700"
              )
            ]}>
              <div>
                <%= month_name(month) %>
              </div>
            </div>
            <div class="flex-1 flex flex-col">
              <%= for {week, schedule_ranges} <- weekly_schedule do %>
                <Schedule.week
                  ctx={@ctx}
                  week_number={week}
                  is_active={
                    week_active?(week, @current_week) &&
                      month_active?(month, @current_month)
                  }
                  is_current_week={
                    is_current_week?(week, @current_week) &&
                      is_current_month?(month, @current_month)
                  }
                  schedule_ranges={schedule_ranges}
                  section_slug={@section_slug}
                  historical_graded_attempt_summary={@historical_graded_attempt_summary}
                />
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp month_name(nil), do: ""

  defp month_name(month) do
    Timex.month_name(month)
  end

  defp week_active?(week_number, current_week) do
    week_number >= current_week
  end

  defp is_current_week?(week_number, current_week) do
    week_number == current_week
  end

  defp month_active?(month, current_month) do
    month >= current_month
  end

  defp is_current_month?(month, current_month) do
    month == current_month
  end

  defp async_scroll_to_current_week(liveview_pid) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      Process.sleep(500)
      send(liveview_pid, {:scroll_to_current_week})
    end)
  end

  def handle_info(
        {:scroll_to_current_week},
        socket
      ) do
    {:noreply,
         socket
         |> push_event("scroll-y-to-target", %{id: "current-week-indicator", offset: 80})}
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

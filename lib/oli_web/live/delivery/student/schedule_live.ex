defmodule OliWeb.Delivery.Student.ScheduleLive do
  use OliWeb, :live_view

  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.{Schedule, Utils}

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]

    schedule = Sections.get_ordered_schedule(section)

    current_datetime = DateTime.utc_now()
    current_week = Utils.week_number(section.start_date, current_datetime)
    current_month = current_datetime.month

    {:ok,
     assign(socket,
       active_tab: :schedule,
       schedule: schedule,
       section_slug: section.slug,
       current_week: current_week,
       current_month: current_month
     )}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-schedule">
      <h1 class="text-6xl mb-8">Course Schedule</h1>
    </.hero_banner>

    <div class="container mx-auto">
      <.schedule
        ctx={@ctx}
        schedule={@schedule}
        section_slug={@section_slug}
        current_week={@current_week}
        current_month={@current_month}
      />
    </div>
    """
  end

  attr :ctx, SessionContext, required: true
  attr :schedule, :any, required: true
  attr :section_slug, :string, required: true
  attr :current_week, :integer, required: true
  attr :current_month, :integer, required: true

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
              "w-full md:w-32 uppercase font-bold border-b md:border-b-0 border-gray-300",
              if(month_active?(month, @current_month),
                do: "text-gray-500",
                else: "text-gray-300 dark:text-gray-700"
              )
            ]}>
              <div class="my-[0.35rem]">
                <%= month_name(month) %>
              </div>
            </div>

            <div class="flex-1 flex flex-col">
              <%= for {week, schedule_ranges} <- weekly_schedule do %>
                <div class="flex flex-row">
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
                  />
                </div>
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
end

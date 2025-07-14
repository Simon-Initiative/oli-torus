defmodule OliWeb.Delivery.Student.ScheduleLive do
  use OliWeb, :live_view

  alias OliWeb.Common.{FormatDateTime, SessionContext}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Scheduling
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Components.Delivery.{Schedule, Utils}
  alias Oli.Delivery.{Attempts, Settings}
  alias Oli.Delivery.Attempts.{HistoricalGradedAttemptSummary}
  alias OliWeb.Components.Utils, as: ComponentsUtils

  def mount(_params, _session, socket) do
    if connected?(socket) do
      section = socket.assigns[:section]
      current_user_id = socket.assigns[:current_user].id

      combined_settings =
        Appsignal.instrument("ScheduleLive: combined_settings", fn ->
          Settings.get_combined_settings_for_all_resources(section.id, current_user_id)
        end)

      has_scheduled_resources? = Scheduling.has_scheduled_resources?(section.id)

      schedule =
        if has_scheduled_resources?,
          do: Sections.get_ordered_schedule(section, current_user_id, combined_settings),
          else:
            Sections.get_not_scheduled_agenda(section, combined_settings, current_user_id)
            |> Map.values()
            |> hd()

      current_datetime = DateTime.utc_now()
      current_week = Utils.week_number(section.start_date, current_datetime)
      current_month = current_datetime.month

      resource_accesses_by_resource_id =
        Core.get_graded_resource_access_for_context(section.id, [current_user_id])
        |> Enum.reduce(%{}, fn access, acc ->
          Map.put(acc, access.resource_id, access)
        end)

      async_scroll_to_current_week(self())

      {:ok,
       assign(socket,
         active_tab: :schedule,
         loaded: true,
         resource_accesses_by_resource_id: resource_accesses_by_resource_id,
         schedule: schedule,
         section_slug: section.slug,
         current_week: current_week,
         current_month: current_month,
         historical_graded_attempt_summary: nil,
         has_scheduled_resources?: has_scheduled_resources?
       )}
    else
      {:ok, assign(socket, active_tab: :schedule, loaded: false)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(%{loaded: false} = assigns) do
    ~H"""
    <div></div>
    """
  end

  def render(%{has_scheduled_resources?: true} = assigns) do
    ~H"""
    <.hero_banner class="bg-schedule">
      <h1 class="text-4xl md:text-6xl mb-8">Course Schedule</h1>
    </.hero_banner>

    <div id="schedule-view" class="container mx-auto h-full" phx-hook="Scroller">
      <.schedule
        ctx={@ctx}
        schedule={@schedule}
        resource_accesses_by_resource_id={@resource_accesses_by_resource_id}
        section_slug={@section_slug}
        current_week={@current_week}
        current_month={@current_month}
        historical_graded_attempt_summary={@historical_graded_attempt_summary}
      />
    </div>
    """
  end

  def render(%{has_scheduled_resources?: false} = assigns) do
    ~H"""
    <.hero_banner class="bg-schedule">
      <h1 class="text-4xl md:text-6xl mb-8">Course Schedule</h1>
    </.hero_banner>

    <div id="schedule-view" class="container mx-auto h-full">
      <div class="my-8 px-3 md:px-16">
        <.schedule_header />
        <div class="flex flex-col">
          <Schedule.non_scheduled_container_groups
            ctx={@ctx}
            non_scheduled_container_groups={@schedule}
            section_slug={@section_slug}
            historical_graded_attempt_summary={@historical_graded_attempt_summary}
            request_path={~p"/sections/#{@section_slug}/student_schedule"}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:ctx, SessionContext, required: true)
  attr(:schedule, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:resource_accesses_by_resource_id, :any, required: true)
  attr(:current_week, :integer, required: true)
  attr(:current_month, :integer, required: true)
  attr(:historical_graded_attempt_summary, HistoricalGradedAttemptSummary)

  def schedule(assigns) do
    ~H"""
    <div class="my-8 px-3 md:px-16" id="schedule_live" phx-hook="Countdown">
      <div class="flex flex-col">
        <div class="text-sm font-medium leading-none mb-6">
          <ComponentsUtils.timezone_info timezone={
            FormatDateTime.tz_preference_or_default(@ctx.author, @ctx.user, @ctx.browser_timezone)
          } />
        </div>
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
                  resource_accesses_by_resource_id={@resource_accesses_by_resource_id}
                  schedule_ranges={schedule_ranges}
                  section_slug={@section_slug}
                  historical_graded_attempt_summary={@historical_graded_attempt_summary}
                  request_path={~p"/sections/#{@section_slug}/student_schedule"}
                />
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def schedule_header(assigns) do
    ~H"""
    <div class="mb-8">
      Scroll though your course schedule to find all critical due dates and when assignments are due.
      Use this schedule view to see which activities you've completed throughout your time in the course.
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

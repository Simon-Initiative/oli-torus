defmodule OliWeb.Delivery.Student.ScheduleLive do
  use OliWeb, :live_view

  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections

  def mount(_params, _session, socket) do
    section = socket.assigns[:section]

    schedule = Sections.get_ordered_schedule(section)

    {:ok,
     assign(socket,
       active_tab: :schedule,
       schedule: schedule
     )}
  end

  def render(assigns) do
    ~H"""
    <.hero_banner class="bg-schedule text-white">
      <h1 class="text-6xl mb-8">Course Schedule</h1>
    </.hero_banner>

    <div class="container mx-auto">
      <.schedule ctx={@ctx} schedule={@schedule} />
    </div>
    """
  end

  attr :ctx, SessionContext, required: true
  attr :schedule, :any, required: true

  def schedule(assigns) do
    ~H"""
    <div class="my-8 px-16">
      <div class="mb-8">
        Scroll though your course schedule to find all critical due dates and when assignments are due. Use this schedule view to see which activities you've completed throughout your time in the course.
      </div>

      <div class="flex flex-col">
        <%= for {{month, _year}, weekly_schedule} <- @schedule do %>
          <div class="flex flex-row">
            <div class="w-32 uppercase"><%= month_name(month) %></div>

            <div class="flex-1 flex flex-col">
              <%= for {week, range_schedules} <- weekly_schedule do %>
                <div class="flex flex-row border-l border-gray-500 px-4">
                  <div class="mr-8 uppercase">Week <%= week %>:</div>

                  <div class="flex-1 flex flex-col">
                    <%= for {date_range, container_groups} <- range_schedules do %>
                      <div class="flex-1 flex flex-col mb-4">
                        <div>
                          <%= render_date_range(date_range, @ctx) %>
                        </div>

                        <%= for {{container_label, graded}, scheduled_resources} <- container_groups do %>
                          <div class="flex flex-row">
                            <div class="basis-1/4 flex flex-col mr-4">
                              <div class="font-bold"><%= graded_label(graded) %></div>
                              <div><%= container_label %></div>
                            </div>
                            <div class="flex-1 flex flex-col mr-4">
                              <%= for resource <- scheduled_resources do %>
                                <div class="flex flex-col mb-4">
                                  <div><%= resource.title %></div>
                                  <div class="text-sm text-gray-500">
                                    Due: <%= date(resource.end_date, ctx: @ctx, precision: :date) %>
                                  </div>
                                </div>
                              <% end %>
                            </div>
                            <div class="basis-1/4 flex flex-col"></div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp graded_label(true), do: "Assessment"
  defp graded_label(_), do: "Pre-Read"

  defp render_date_range({start_date, end_date}, ctx) do
    cond do
      date(start_date, ctx: ctx, precision: :day) == date(end_date, ctx: ctx, precision: :day) ->
        start_date

      is_nil(start_date) ->
        "Due #{date(end_date, ctx: ctx, precision: :day)}"

      is_nil(end_date) ->
        "Start #{date(start_date, ctx: ctx, precision: :day)}"

      true ->
        "#{date(start_date, ctx: ctx, precision: :day)} - #{date(end_date, ctx: ctx, precision: :day)}"
    end
  end

  defp month_name(nil), do: ""

  defp month_name(month) do
    Timex.month_name(month)
  end
end

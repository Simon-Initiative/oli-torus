defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias OliWeb.Common.SessionContext

  attr(:ctx, SessionContext, required: true)
  attr(:week_number, :integer, required: true)
  attr(:is_active, :boolean, required: true)
  attr(:is_current_week, :boolean, required: true)
  attr(:schedule_ranges, :any, required: true)
  attr(:section_slug, :string, required: true)

  def week(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class={[
        "uppercase font-bold whitespace-nowrap mr-4 md:w-32 md:border-l",
        if(@is_active,
          do: "text-gray-600 dark:text-gray-300 md:border-gray-500",
          else: "text-gray-300 dark:text-gray-700 md:border-gray-300 dark:border-gray-700"
        )
      ]}>
        <div class="inline-flex items-center">
          <.maybe_current_week_indicator is_current_week={@is_current_week} />
          <div>Week <%= @week_number %>:</div>
        </div>
      </div>

      <div class="flex-1 flex flex-col">
        <%= for {date_range, container_groups} <- @schedule_ranges do %>
          <div class={[
            "flex-1 flex flex-col mb-4 group",
            if(start_or_end_date_past?(date_range),
              do: "past-start text-gray-300 dark:text-gray-700",
              else: ""
            )
          ]}>
            <div class="font-bold text-gray-500 group-[.past-start]:text-gray-300 dark:group-[.past-start]:text-gray-700">
              <%= render_date_range(date_range, @ctx) %>
            </div>

            <%= for {{resource_label, graded}, scheduled_resources} <- container_groups do %>
              <div class="flex flex-row text-gray-600 dark:text-gray-300 group-[.past-start]:text-gray-300 dark:group-[.past-start]:text-gray-700">
                <div class="flex flex-col mr-4 md:w-64">
                  <div><%= page_or_assessment_label(graded) %></div>
                  <div>
                    <%= resource_label %>
                  </div>
                </div>
                <div class="flex-1 flex flex-col mr-4">
                  <%= for resource <- scheduled_resources do %>
                    <div class="flex flex-col mb-4">
                      <div>
                        <.link
                          href={~p"/sections/#{@section_slug}/lesson/#{resource.revision_slug}"}
                          class="hover:no-underline"
                        >
                          <%= resource.title %>
                        </.link>
                      </div>
                      <div class="text-sm">
                        <%= resource_scheduling_label(resource.scheduling_type) %> <%= date(
                          resource.end_date,
                          ctx: @ctx,
                          precision: :date
                        ) %>
                      </div>
                    </div>
                  <% end %>
                </div>
                <div class="flex flex-col"></div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :is_current_week, :boolean, default: false

  defp maybe_current_week_indicator(assigns) do
    ~H"""
    <div
      :if={@is_current_week}
      class="w-0 h-0 border-[8px] border-solid border-transparent border-l-gray-600 dark:border-l-gray-300"
    >
    </div>
    <div :if={!@is_current_week} class="ml-[16px]"></div>
    """
  end

  defp resource_scheduling_label(:due_by), do: "Due By:"
  defp resource_scheduling_label(:read_by), do: "Read By:"
  defp resource_scheduling_label(:inclass_activity), do: "In-Class Activity:"
  defp resource_scheduling_label(_), do: ""

  defp page_or_assessment_label(true), do: "Assessment"
  defp page_or_assessment_label(_), do: "Pre-Read"

  defp render_date_range({start_date, end_date}, ctx) do
    cond do
      date(start_date, ctx: ctx, precision: :day) == date(end_date, ctx: ctx, precision: :day) ->
        date(start_date, ctx: ctx, precision: :day)

      is_nil(start_date) ->
        date(end_date, ctx: ctx, precision: :day)

      is_nil(end_date) ->
        date(start_date, ctx: ctx, precision: :day)

      true ->
        "#{date(start_date, ctx: ctx, precision: :day)} — #{date(end_date, ctx: ctx, precision: :day)}"
    end
  end

  defp start_or_end_date_past?({start_date, end_date}) do
    today = DateTime.utc_now()

    dbg({today, start_date, end_date, today > start_date, today > end_date})

    if is_nil(start_date) do
      DateTime.after?(today, end_date)
    else
      DateTime.after?(today, start_date)
    end
  end
end

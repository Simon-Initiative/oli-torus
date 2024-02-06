defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias OliWeb.Common.SessionContext

  attr(:ctx, SessionContext, required: true)
  attr(:week_number, :integer, required: true)
  attr(:schedule_ranges, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:is_active, :boolean, default: true)
  attr(:is_current_week, :boolean, default: false)

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
        <div class="flex flex-row">
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

            <%= for {_container_id, container_label, graded, container_progress, scheduled_resources_with_progress} <- container_groups do %>
              <div class="flex flex-row">
                <div class="flex flex-col mr-4 md:w-64">
                  <div class="flex flex-row">
                    <.progress_icon progress={container_progress} />
                    <div>
                      <%= page_or_assessment_label(graded) %>
                      <div class="uppercase font-bold text-sm text-gray-500 group-[.past-start]:text-gray-300 dark:group-[.past-start]:text-gray-700">
                        <%= container_label %>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="flex-1 flex flex-col mr-4">
                  <%= for {resource, progress} <- scheduled_resources_with_progress do %>
                    <div class="flex flex-col mb-4">
                      <div class="flex flex-row">
                        <.progress_icon progress={progress} />
                        <div>
                          <.link
                            href={~p"/sections/#{@section_slug}/lesson/#{resource.revision_slug}"}
                            class="hover:no-underline"
                          >
                            <%= resource.title %>
                          </.link>

                          <div class="text-sm text-gray-500 group-[.past-start]:text-gray-300 dark:group-[.past-start]:text-gray-700">
                            <%= resource_scheduling_label(resource.scheduling_type) %> <%= date(
                              resource.end_date,
                              ctx: @ctx,
                              precision: :date
                            ) %>
                          </div>
                        </div>
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
      class="w-0 h-0 my-[4px] border-[8px] border-solid border-transparent border-l-gray-600 dark:border-l-gray-300"
    >
    </div>
    <div :if={!@is_current_week} class="w-0 h-0 ml-[16px]"></div>
    """
  end

  attr(:progress, :integer, required: true)

  defp progress_icon(assigns) do
    ~H"""
    <div class="w-[28px]">
      <svg
        :if={@progress == 100}
        xmlns="http://www.w3.org/2000/svg"
        width="25"
        height="24"
        viewBox="0 0 25 24"
        fill="none"
        role="completed check icon"
      >
        <path
          d="M10.0496 17.9996L4.34961 12.2996L5.77461 10.8746L10.0496 15.1496L19.2246 5.97461L20.6496 7.39961L10.0496 17.9996Z"
          fill="#0CAF61"
        />
      </svg>
      <svg
        :if={is_nil(@progress) || @progress < 100}
        xmlns="http://www.w3.org/2000/svg"
        class="m-2"
        width="8"
        height="8"
        viewBox="0 0 8 8"
        fill="none"
      >
        <circle
          cx="4"
          cy="4"
          r="4"
          class="fill-gray-700 dark:fill-white group-[.past-start]:fill-gray-300 dark:group-[.past-start]:fill-gray-700"
        />
      </svg>
    </div>
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

    if is_nil(start_date) do
      DateTime.after?(today, end_date)
    else
      DateTime.after?(today, start_date)
    end
  end
end

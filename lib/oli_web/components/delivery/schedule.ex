defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias OliWeb.Common.SessionContext
  alias OliWeb.Components.Delivery.Student
  alias Oli.Delivery.Attempts.HistoricalGradedAttemptSummary
  alias Oli.Delivery.Sections.{ScheduledContainerGroup, ScheduledSectionResource}
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons

  attr(:ctx, SessionContext, required: true)
  attr(:week_number, :integer, required: true)
  attr(:schedule_ranges, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:is_active, :boolean, default: true)
  attr(:is_current_week, :boolean, default: false)
  attr(:show_border, :boolean, default: true)
  attr(:historical_graded_attempt_summary, HistoricalGradedAttemptSummary)
  attr(:request_path, :string, required: false)

  def week(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class={[
        "uppercase font-bold whitespace-nowrap mr-4 md:w-32",
        if(@show_border, do: "md:border-l"),
        if(@is_active,
          do: "text-gray-700 dark:text-gray-300 md:border-gray-700 md:dark:border-gray-300",
          else: "text-gray-400 dark:text-gray-700 md:border-gray-500 dark:border-gray-700"
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
              do: "past-start text-gray-400 dark:text-gray-700",
              else: ""
            )
          ]}>
            <div class="font-bold text-gray-700 dark:text-gray-300 group-[.past-start]:text-gray-400 dark:group-[.past-start]:text-gray-700">
              <%= render_date_range(date_range, @ctx) %>
            </div>

            <%= for %ScheduledContainerGroup{container_label: container_label, graded: graded, progress: container_progress, resources: scheduled_resources} <- container_groups do %>
              <div class="flex flex-row">
                <div class="flex flex-col mr-4 md:w-64">
                  <div class="flex flex-row">
                    <.progress_icon progress={container_progress} />
                    <div>
                      <%= page_or_assessment_label(graded) %>
                      <div class="uppercase font-bold text-sm text-gray-700 dark:text-gray-300 group-[.past-start]:text-gray-400 dark:group-[.past-start]:text-gray-700">
                        <%= container_label %>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="flex-1 flex flex-col mr-4">
                  <%= for %ScheduledSectionResource{
                      resource: resource,
                      purpose: purpose,
                      progress: progress,
                      raw_avg_score: raw_avg_score,
                      resource_attempt_count: resource_attempt_count,
                      effective_settings: effective_settings
                    } <- scheduled_resources do %>
                    <div class="flex flex-row gap-4 mb-3">
                      <.page_icon progress={progress} graded={graded} purpose={purpose} />
                      <div class="flex-1">
                        <.link
                          href={
                            Utils.lesson_live_path(@section_slug, resource.revision_slug,
                              request_path: @request_path
                            )
                          }
                          class="hover:no-underline"
                        >
                          <%= resource.title %>
                        </.link>

                        <div class="text-sm text-gray-700 dark:text-gray-300 group-[.past-start]:text-gray-400 dark:group-[.past-start]:text-gray-700">
                          <%= resource_scheduling_label(resource.scheduling_type) %> <%= date(
                            resource.end_date,
                            ctx: @ctx,
                            precision: :date
                          ) %>
                        </div>
                      </div>
                      <div :if={graded} class="flex flex-col">
                        <Student.attempts_dropdown
                          ctx={@ctx}
                          section_slug={@section_slug}
                          page_revision_slug={resource.revision_slug}
                          attempt_summary={@historical_graded_attempt_summary}
                          attempts_count={resource_attempt_count}
                          effective_settings={effective_settings}
                        />
                        <Student.score_summary raw_avg_score={raw_avg_score} />
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:is_current_week, :boolean, default: false)

  defp maybe_current_week_indicator(assigns) do
    ~H"""
    <div
      :if={@is_current_week}
      id="current-week-indicator"
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
      <div :if={@progress == 100}>
        <Icons.check progress={1.0} />
      </div>
      <div :if={is_nil(@progress) || @progress < 100}>
        <Icons.bullet />
      </div>
    </div>
    """
  end

  attr(:progress, :integer, required: true)
  attr(:graded, :boolean, required: true)
  attr(:purpose, :atom, required: true)

  defp page_icon(assigns) do
    ~H"""
    <div class="w-[36px] shrink-0">
      <%= cond do %>
        <% @purpose == :application -> %>
          <Icons.exploration />
        <% @graded && @progress == 100 -> %>
          <<<<<<< HEAD <Icons.square_checked /> =======
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            class="fill-[#0caf61] group-[.past-start]:fill-[#89c8aa] dark:group-[.past-start]:fill-[#085c36]"
          >
            <path d="M5 21C4.45 21 3.97917 20.8042 3.5875 20.4125C3.19583 20.0208 3 19.55 3 19V5C3 4.45 3.19583 3.97917 3.5875 3.5875C3.97917 3.19583 4.45 3 5 3H17.925L15.925 5H5V19H19V12.05L21 10.05V19C21 19.55 20.8042 20.0208 20.4125 20.4125C20.0208 20.8042 19.55 21 19 21H5Z" />
            <path d="M11.7 16.025L6 10.325L7.425 8.9L11.7 13.175L20.875 4L22.3 5.425L11.7 16.025Z" />
          </svg>
          >>>>>>> master
        <% @graded -> %>
          <Icons.flag />
        <% @progress == 100 -> %>
          <<<<<<< HEAD <Icons.check progress={1.0} />
        <% true -> %>
          <Icons.bullet /> =======
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="25"
            height="24"
            viewBox="0 0 25 24"
            fill="none"
            role="completed check icon"
          >
            <path
              d="M10.0496 17.9996L4.34961 12.2996L5.77461 10.8746L10.0496 15.1496L19.2246 5.97461L20.6496 7.39961L10.0496 17.9996Z"
              class="fill-[#0caf61] group-[.past-start]:fill-[#89c8aa] dark:group-[.past-start]:fill-[#085c36]"
            />
          </svg>
        <% true -> %>
          <svg
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
              class="fill-gray-700 dark:fill-white group-[.past-start]:fill-gray-400 dark:group-[.past-start]:fill-gray-700"
            />
          </svg>
          >>>>>>> master
      <% end %>
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

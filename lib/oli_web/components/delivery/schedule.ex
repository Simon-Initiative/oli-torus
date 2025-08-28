defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias Oli.Delivery.Attempts.HistoricalGradedAttemptSummary
  alias Oli.Delivery.Sections.{ScheduledContainerGroup, ScheduledSectionResource}
  alias OliWeb.Common.SessionContext
  alias OliWeb.Components.Delivery.Student
  alias OliWeb.Icons
  alias OliWeb.Delivery.Student.Utils

  attr(:ctx, SessionContext, required: true)
  attr(:week_number, :integer, required: true)
  attr(:schedule_ranges, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:is_active, :boolean, default: true)

  attr(:resource_accesses_by_resource_id, :map, default: %{})
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
          <div>Week {@week_number}:</div>
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
              {render_date_range(date_range, @ctx)}
            </div>

            <%= for %ScheduledContainerGroup{module_label: module_label, unit_label: unit_label, graded: graded, progress: container_progress, resources: scheduled_resources} <- container_groups do %>
              <% container_label = module_label || unit_label %>
              <div class="flex flex-row">
                <div class="flex flex-col mr-4 md:w-64">
                  <div class="flex flex-row">
                    <.progress_icon progress={container_progress} />
                    <div>
                      {page_or_assessment_label(graded)}
                      <div class="uppercase font-bold text-sm text-gray-700 dark:text-gray-300 group-[.past-start]:text-gray-400 dark:group-[.past-start]:text-gray-700">
                        {container_label}
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
                      <div class="flex flex-col md:flex-row gap-2 md:gap-6">
                        <div class="flex-1">
                          <.link
                            href={
                              Utils.lesson_live_path(@section_slug, resource.revision_slug,
                                request_path: @request_path
                              )
                            }
                            class="hover:no-underline"
                          >
                            {resource.title}
                          </.link>

                          <div class="text-sm text-gray-700 dark:text-gray-300 group-[.past-start]:text-gray-400 dark:group-[.past-start]:text-gray-700">
                            <span>
                              Available:
                              <%= if effective_settings.start_date do %>
                                {date(effective_settings.start_date, ctx: @ctx, precision: :date)}
                              <% else %>
                                Now
                              <% end %>
                            </span>
                            <span class="ml-6">
                              {resource_scheduling_label(resource.scheduling_type)}
                              {if is_nil(effective_settings),
                                do:
                                  date(
                                    Utils.coalesce(resource.end_date, resource.start_date),
                                    ctx: @ctx,
                                    precision: :date
                                  ),
                                else:
                                  date(
                                    Utils.coalesce(
                                      effective_settings.end_date,
                                      effective_settings.start_date
                                    ),
                                    ctx: @ctx,
                                    precision: :date
                                  )}
                            </span>
                          </div>
                        </div>

                        <%= if graded do %>
                          <div class="flex flex-col justify-center">
                            <Student.attempts_dropdown
                              ctx={@ctx}
                              resource_access={
                                Map.get(@resource_accesses_by_resource_id, resource.resource_id)
                              }
                              section_slug={@section_slug}
                              page_revision_slug={resource.revision_slug}
                              attempt_summary={@historical_graded_attempt_summary}
                              attempts_count={resource_attempt_count}
                              effective_settings={effective_settings}
                            />
                            <%= if effective_settings.batch_scoring do %>
                              <Student.score_summary raw_avg_score={raw_avg_score} />
                            <% else %>
                              <Student.score_as_you_go_summary raw_avg_score={raw_avg_score} />
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
        <% end %>
      </div>
    </div>
    """
  end

  attr(:ctx, SessionContext, required: true)
  attr(:non_scheduled_container_groups, :any, required: true)
  attr(:section_slug, :string, required: true)
  attr(:historical_graded_attempt_summary, HistoricalGradedAttemptSummary)
  attr(:request_path, :string, required: false)

  def non_scheduled_container_groups(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class="flex-1 flex flex-col md:p-[25px] md:pl-[125px] md:pr-[175px]">
        <%= for %ScheduledContainerGroup{module_id: module_id, unit_id: unit_id, unit_label: unit_label, container_title: title, resources: scheduled_resources} <- @non_scheduled_container_groups do %>
          <div class="flex flex-row">
            <div class="flex-1 flex flex-col mr-4">
              <.container_label
                module_id={module_id}
                unit_id={unit_id}
                unit_label={unit_label}
                title={title}
              />

              <div class="flex flex-col my-6 ml-10">
                <%= for %ScheduledSectionResource{
                      resource: resource,
                      purpose: purpose,
                      progress: progress,
                      raw_avg_score: raw_avg_score,
                      resource_attempt_count: resource_attempt_count,
                      effective_settings: effective_settings,
                      graded: graded
                    } <- Enum.sort_by(scheduled_resources, fn sr -> sr.resource.numbering_index end) do %>
                  <div class="flex flex-row items-center gap-4 p-2.5 rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5">
                    <div class="flex items-center">
                      <.non_scheduled_page_icon progress={progress} graded={graded} purpose={purpose} />
                      <div class="w-[26px] justify-start items-center">
                        <div class="grow shrink basis-0 opacity-60 dark:text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
                          {resource.numbering_index}
                        </div>
                      </div>
                    </div>
                    <div class="flex flex-col md:flex-row gap-2 md:gap-6">
                      <div class="flex-1">
                        <.link
                          href={
                            Utils.lesson_live_path(@section_slug, resource.revision_slug,
                              request_path: @request_path
                            )
                          }
                          class="text-left dark:text-white opacity-90 text-base font-['Open Sans'] hover:no-underline"
                        >
                          {resource.title}
                        </.link>
                      </div>
                      <div :if={graded} class="flex flex-col justify-center">
                        <Student.attempts_dropdown
                          ctx={@ctx}
                          section_slug={@section_slug}
                          page_revision_slug={resource.revision_slug}
                          attempt_summary={@historical_graded_attempt_summary}
                          attempts_count={resource_attempt_count}
                          effective_settings={effective_settings}
                        />
                        <%= if effective_settings.batch_scoring do %>
                          <Student.score_summary raw_avg_score={raw_avg_score} />
                        <% else %>
                          <Student.score_as_you_go_summary raw_avg_score={raw_avg_score} />
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def container_label(%{module_id: module_id} = assigns) when not is_nil(module_id) do
    ~H"""
    <h3 class="ml-12 dark:text-white text-base font-bold font-['Open Sans']">
      {@title}
    </h3>
    """
  end

  def container_label(%{unit_id: unit_id} = assigns) when not is_nil(unit_id) do
    ~H"""
    <h3 class="dark:text-white text-xl font-bold font-['Open Sans']">
      {"#{@unit_label}: #{@title}"}
    </h3>
    """
  end

  def container_label(assigns) do
    ~H"""
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

  defp non_scheduled_page_icon(assigns) do
    ~H"""
    <div class="w-[36px] shrink-0">
      <%= cond do %>
        <% @purpose == :application -> %>
          <Icons.exploration />
        <% @graded && @progress == 100 -> %>
          <Icons.square_checked />
        <% @graded -> %>
          <Icons.flag />
        <% @progress == 100 -> %>
          <Icons.check progress={1.0} />
        <% true -> %>
          <div role="no icon" class="flex justify-center items-center"></div>
      <% end %>
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
          <Icons.square_checked />
        <% @graded -> %>
          <Icons.flag />
        <% @progress == 100 -> %>
          <Icons.check progress={1.0} />
        <% true -> %>
          <Icons.bullet />
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

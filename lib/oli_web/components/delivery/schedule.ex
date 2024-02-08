defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias OliWeb.Common.SessionContext
  alias OliWeb.Components.Delivery.Student

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
          do: "text-gray-600 dark:text-gray-300 md:border-gray-600 md:dark:border-gray-300",
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
                  <%= for {resource, purpose, progress, raw_avg_score} <- scheduled_resources_with_progress do %>
                    <div class="flex flex-col mb-4">
                      <div class="flex flex-row">
                        <.page_icon progress={progress} graded={graded} purpose={purpose} />
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
                      <Student.score_summary :if={graded} raw_avg_score={raw_avg_score} />
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
          class="fill-[#0caf61] group-[.past-start]:fill-[#acd8c3] dark:group-[.past-start]:fill-[#085c36]"
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

  attr(:progress, :integer, required: true)
  attr(:graded, :boolean, required: true)
  attr(:purpose, :atom, required: true)

  defp page_icon(assigns) do
    ~H"""
    <div class="w-[36px] shrink-0">
      <%= cond do %>
        <% @graded && @progress == 100 -> %>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            class="fill-[#0caf61] group-[.past-start]:fill-[#acd8c3] dark:group-[.past-start]:fill-[#085c36]"
          >
            <path d="M5 21C4.45 21 3.97917 20.8042 3.5875 20.4125C3.19583 20.0208 3 19.55 3 19V5C3 4.45 3.19583 3.97917 3.5875 3.5875C3.97917 3.19583 4.45 3 5 3H17.925L15.925 5H5V19H19V12.05L21 10.05V19C21 19.55 20.8042 20.0208 20.4125 20.4125C20.0208 20.8042 19.55 21 19 21H5Z" />
            <path d="M11.7 16.025L6 10.325L7.425 8.9L11.7 13.175L20.875 4L22.3 5.425L11.7 16.025Z" />
          </svg>
        <% @graded -> %>
          <svg
            width="15"
            height="17"
            viewBox="0 0 15 17"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            class="m-1 fill-[#f68e2d] group-[.past-start]:fill-[#f6cba4] dark:group-[.past-start]:fill-[#7f4b1e]"
          >
            <path d="M0 17V0H9L9.4 2H15V12H8L7.6 10H2V17H0Z" />
          </svg>
        <% @purpose == :application -> %>
          <svg
            width="21"
            height="20"
            viewBox="0 0 21 20"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            class="m-1 fill-[#b982ff] group-[.past-start]:fill-[#e3cdff] dark:group-[.past-start]:fill-[#66488c]"
          >
            <path d="M10 20C8.61667 20 7.31667 19.7375 6.1 19.2125C4.88333 18.6875 3.825 17.975 2.925 17.075C2.025 16.175 1.3125 15.1167 0.7875 13.9C0.2625 12.6833 0 11.3833 0 10C0 8.61667 0.2625 7.31667 0.7875 6.1C1.3125 4.88333 2.025 3.825 2.925 2.925C3.825 2.025 4.88333 1.3125 6.1 0.7875C7.31667 0.2625 8.61667 0 10 0C12.4333 0 14.5625 0.7625 16.3875 2.2875C18.2125 3.8125 19.35 5.725 19.8 8.025H17.75C17.4333 6.80833 16.8625 5.72083 16.0375 4.7625C15.2125 3.80417 14.2 3.08333 13 2.6V3C13 3.55 12.8042 4.02083 12.4125 4.4125C12.0208 4.80417 11.55 5 11 5H9V7C9 7.28333 8.90417 7.52083 8.7125 7.7125C8.52083 7.90417 8.28333 8 8 8H6V10H8V13H7L2.2 8.2C2.15 8.5 2.10417 8.8 2.0625 9.1C2.02083 9.4 2 9.7 2 10C2 12.1833 2.76667 14.0583 4.3 15.625C5.83333 17.1917 7.73333 17.9833 10 18V20ZM19.1 19.5L15.9 16.3C15.55 16.5 15.175 16.6667 14.775 16.8C14.375 16.9333 13.95 17 13.5 17C12.25 17 11.1875 16.5625 10.3125 15.6875C9.4375 14.8125 9 13.75 9 12.5C9 11.25 9.4375 10.1875 10.3125 9.3125C11.1875 8.4375 12.25 8 13.5 8C14.75 8 15.8125 8.4375 16.6875 9.3125C17.5625 10.1875 18 11.25 18 12.5C18 12.95 17.9333 13.375 17.8 13.775C17.6667 14.175 17.5 14.55 17.3 14.9L20.5 18.1L19.1 19.5ZM13.5 15C14.2 15 14.7917 14.7583 15.275 14.275C15.7583 13.7917 16 13.2 16 12.5C16 11.8 15.7583 11.2083 15.275 10.725C14.7917 10.2417 14.2 10 13.5 10C12.8 10 12.2083 10.2417 11.725 10.725C11.2417 11.2083 11 11.8 11 12.5C11 13.2 11.2417 13.7917 11.725 14.275C12.2083 14.7583 12.8 15 13.5 15Z" />
          </svg>
        <% @progress == 100 -> %>
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
              class="fill-[#0caf61] group-[.past-start]:fill-[#acd8c3] dark:group-[.past-start]:fill-[#085c36]"
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
              class="fill-gray-700 dark:fill-white group-[.past-start]:fill-gray-300 dark:group-[.past-start]:fill-gray-700"
            />
          </svg>
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

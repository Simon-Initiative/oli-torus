defmodule OliWeb.Components.Delivery.Schedule do
  use OliWeb, :html

  alias OliWeb.Common.SessionContext

  attr(:ctx, SessionContext, required: true)
  attr(:week_number, :any, required: true)
  attr(:schedule_ranges, :any, required: true)
  attr(:section_slug, :string, required: true)

  def week(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class="mr-8 uppercase font-bold text-gray-500 whitespace-nowrap">
        Week <%= @week_number %>:
      </div>

      <div class="flex-1 flex flex-col">
        <%= for {date_range, container_groups} <- @schedule_ranges do %>
          <div class="flex-1 flex flex-col mb-4">
            <div class="font-bold text-gray-500">
              <%= render_date_range(date_range, @ctx) %>
            </div>

            <%= for {{resource_label, graded}, scheduled_resources} <- container_groups do %>
              <div class="flex flex-row">
                <div class="basis-1/4 flex flex-col mr-4">
                  <div><%= page_or_assessment_label(graded) %></div>
                  <div class="text-gray-500">
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
                      <div class="text-sm text-gray-500">
                        <%= resource_scheduling_label(resource.scheduling_type) %> <%= date(
                          resource.end_date,
                          ctx: @ctx,
                          precision: :date
                        ) %>
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
end

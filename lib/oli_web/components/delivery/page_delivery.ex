defmodule OliWeb.Components.Delivery.PageDelivery do
  use Phoenix.Component

  import OliWeb.Common.FormatDateTime

  alias OliWeb.Common.SessionContext
  alias OliWeb.Components.Delivery.PageNavigator

  attr(:title, :string, required: true)
  attr(:page_number, :integer, required: true)
  attr(:review_mode, :boolean, required: true)
  attr(:next_page, :map)
  attr(:previous_page, :map)
  attr(:preview_mode, :boolean, default: false)
  attr(:section_slug, :string, required: true)
  attr(:numbered_revisions, :list, default: [])

  def header(assigns) do
    ~H"""
    <h1 class="title flex flex-row items-center justify-between mb-2">
      {@title}
      <%= if @review_mode == true do %>
        (Review)
      <% end %>
      <%= case assigns do %>
        <% %{previous_page: _, next_page: _, numbered_revisions: _, section_slug: _} -> %>
          <PageNavigator.render
            id="top_page_navigator"
            page_number={@page_number}
            next_page={assigns[:next_page]}
            previous_page={assigns[:previous_page]}
            preview_mode={@preview_mode}
            section_slug={@section_slug}
            numbered_revisions={assigns[:numbered_revisions]}
          />
        <% _ -> %>
      <% end %>
    </h1>
    """
  end

  attr(:ctx, SessionContext, required: true)
  attr(:scheduling_type, :atom, values: [:read_by, :inclass_activity])
  attr(:end_date, Date, default: nil)
  attr(:est_reading_time, Timex.Duration, default: nil)

  def details(assigns) do
    ~H"""
    <div class="flex flex-row my-2">
      <%= if @end_date do %>
        <div class="py-1.5 px-4 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-delivery-body-color-dark rounded">
          {scheduling_type_label(@scheduling_type)} {date(@end_date, @ctx)}
        </div>
      <% end %>
      <%= if @est_reading_time do %>
        <div class="py-1.5 px-4 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-delivery-body-color-dark rounded ml-1">
          Estimated reading time: {duration(@est_reading_time)}
        </div>
      <% end %>
    </div>
    """
  end

  defp scheduling_type_label(:due_by), do: "Due by"
  defp scheduling_type_label(:read_by), do: "Read by"
  defp scheduling_type_label(:inclass_activity), do: "In-class activity"

  attr(:objectives, :list, required: true)

  def learning_objectives(assigns) do
    ~H"""
    <%= if length(@objectives) > 0 do %>
      <div class="objectives p-4 rounded-lg bg-gray-100 dark:bg-gray-700">
        <div class="uppercase font-bold mb-2">Learning Objectives</div>
        <ul class="list-none">
          <%= for title <- @objectives do %>
            <li class="objective mt-2">{title}</li>
          <% end %>
        </ul>
      </div>
    <% end %>
    """
  end
end

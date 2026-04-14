defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile do
  @moduledoc """
  Summary tile surface for `MER-5249`.
  """

  use OliWeb, :live_component

  alias OliWeb.Icons

  @tooltip_copy %{
    average_student_progress:
      "Shows how far students, on average, have progressed through the course.",
    average_class_proficiency:
      "Shows your class’s average proficiency based on how often students answer learning-objective questions correctly on their first attempt.",
    average_assessment_score: "Shows your class’s current average score on assessment pages."
  }

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    projection = Map.get(assigns, :projection, socket.assigns[:projection] || %{})

    projection_status =
      Map.get(
        assigns,
        :projection_status,
        socket.assigns[:projection_status] || %{status: :loading}
      )

    tile_state =
      Map.get(assigns, :tile_state, socket.assigns[:tile_state] || default_tile_state())

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:projection, projection)
     |> assign(:projection_status, projection_status)
     |> assign(:tile_state, Map.merge(default_tile_state(), tile_state))
     |> assign(:cards, Map.get(projection, :cards, []))
     |> assign(:recommendation, Map.get(projection, :recommendation, default_recommendation()))
     |> assign(
       :layout,
       Map.get(projection, :layout, %{visible_card_count: 0, card_grid_class: "grid-cols-1"})
     )
     |> assign(:scope_label, Map.get(projection, :scope_label))
     |> assign(:course_title, Map.get(projection, :course_title))}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <article
      id="learning-dashboard-summary-tile"
      aria-label="Summary"
      class="space-y-4"
    >
      <h3 class="sr-only">Summary</h3>

      <section
        id={"learning-dashboard-summary-metrics-#{@id}"}
        aria-label={summary_scope_copy(@scope_label, @course_title)}
        class="rounded-2xl bg-[linear-gradient(90deg,#6D3C97_0%,#2D628E_46%,#0DBBD3_100%)] px-[23px] py-[22px] shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
      >
        <div class={["grid items-stretch gap-2", row_grid_classes(@layout)]}>
          <%= if @cards == [] do %>
            <div class="rounded-2xl bg-Surface-surface-secondary px-6 py-5 text-sm leading-6 text-Text-text-high opacity-80 lg:col-span-3">
              Summary metrics will appear as scoped progress, proficiency, and assessment data become available.
            </div>
          <% else %>
            <%= for card <- @cards do %>
              <section
                id={"summary-metric-card-#{card.id}"}
                class="h-full min-h-[10.375rem] rounded-2xl bg-Surface-surface-secondary py-6 pl-6 pr-[15px] text-Text-text-high shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
              >
                <div class="relative flex h-full flex-col">
                  <div class="min-w-0 pr-8">
                    <div class="min-h-[40px] min-w-0 space-y-1">
                      <p class="font-open-sans text-[16px] font-bold leading-[16px] tracking-[0] text-Text-text-high">
                        {card_title_line_one(card.label)}
                      </p>
                      <p class="whitespace-nowrap font-open-sans text-[16px] font-bold leading-[16px] tracking-[0] text-Text-text-high">
                        {card_title_line_two(card.label)}
                      </p>
                    </div>
                  </div>

                  <p class="mt-3 font-open-sans text-[40px] font-semibold leading-[54px] tracking-[0] text-Text-text-high">
                    {card.value_text}
                  </p>

                  <div class="group absolute right-0 top-5 shrink-0 text-Text-text-high">
                    <button
                      id={"summary-tooltip-trigger-#{card.id}"}
                      type="button"
                      aria-label={"#{card.label} definition"}
                      aria-describedby={"summary-tooltip-#{card.id}"}
                      class="inline-flex h-5 w-5 items-center justify-center rounded-full transition hover:opacity-80 focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70"
                    >
                      <span class="scale-[0.9]">
                        <Icons.info />
                      </span>
                    </button>
                    <div
                      id={"summary-tooltip-#{card.id}"}
                      role="tooltip"
                      class="pointer-events-none absolute right-0 top-[calc(100%+8px)] z-20 hidden w-64 rounded-sm border border-Border-border-default bg-Surface-surface-background px-3 py-2 text-xs leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block"
                    >
                      {tooltip_copy(card.tooltip_key)}
                    </div>
                  </div>
                </div>
              </section>
            <% end %>
          <% end %>
          <section
            id={"summary-recommendation-panel-#{@id}"}
            aria-labelledby={"summary-recommendation-title-#{@id}"}
            aria-label={Map.get(@recommendation, :aria_label, @recommendation.label)}
            class="flex h-full min-h-[10.375rem] flex-col rounded-2xl bg-Surface-surface-secondary pb-3 pl-6 pr-4 pt-6 text-Text-text-high"
          >
            <div class="flex min-w-0 items-center gap-[4px]">
              <div class="relative h-[29px] w-[29px] shrink-0">
                <div class="absolute inset-[4px] overflow-hidden rounded-full">
                  <img
                    src={~p"/images/assistant/dot_ai_icon.png"}
                    class="absolute inset-y-0 left-[2px] h-full w-full scale-[1.95] rounded-full object-cover"
                    alt=""
                    aria-hidden="true"
                  />
                </div>
              </div>
              <h4
                id={"summary-recommendation-title-#{@id}"}
                class="text-[0.875rem] font-bold uppercase leading-4 text-Text-text-high"
              >
                {@recommendation.label}
              </h4>
              <span class="sr-only">{status_badge(@projection_status)}</span>
              <span class="sr-only">{recommendation_status_label(@recommendation.status)}</span>
            </div>

            <div class="flex flex-1 flex-col pl-[33px] pr-[28px]">
              <p class="mt-[6px] max-w-[41.4375rem] text-base leading-6 text-Text-text-high">
                {recommendation_body(@recommendation)}
              </p>

              <div class="mt-auto flex items-center justify-end gap-[10px] pb-[10px] pr-[10px] text-Icon-icon-default">
                <button
                  type="button"
                  phx-click="summary_recommendation_sentiment_submitted"
                  phx-value-recommendation_id={Map.get(@recommendation, :recommendation_id)}
                  phx-value-sentiment="up"
                  aria-label="Thumbs up recommendation"
                  disabled={sentiment_disabled?(@recommendation, @tile_state)}
                  class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-default disabled:opacity-60"
                >
                  <Icons.thumbs_up_ai class="stroke-current" />
                </button>
                <button
                  type="button"
                  phx-click="summary_recommendation_sentiment_submitted"
                  phx-value-recommendation_id={Map.get(@recommendation, :recommendation_id)}
                  phx-value-sentiment="down"
                  aria-label="Thumbs down recommendation"
                  disabled={sentiment_disabled?(@recommendation, @tile_state)}
                  class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-default disabled:opacity-60"
                >
                  <Icons.thumbs_down_ai class="stroke-current" />
                </button>
                <button
                  type="button"
                  phx-click="summary_recommendation_regenerate_requested"
                  phx-value-recommendation_id={Map.get(@recommendation, :recommendation_id)}
                  aria-label="Regenerate recommendation"
                  disabled={
                    !Map.get(@recommendation, :can_regenerate?, false) or
                      @tile_state.regenerate_in_flight?
                  }
                  class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-default disabled:opacity-60"
                >
                  <Icons.regenerate_ai class="stroke-current" />
                </button>
              </div>
            </div>
          </section>
        </div>
      </section>
    </article>
    """
  end

  defp default_tile_state do
    %{regenerate_in_flight?: false, submitted_sentiment: nil, last_recommendation_id: nil}
  end

  defp sentiment_disabled?(recommendation, tile_state) do
    not Map.get(recommendation, :can_submit_sentiment?, false) or
      tile_state.regenerate_in_flight? or
      sentiment_already_submitted?(recommendation, tile_state)
  end

  defp sentiment_already_submitted?(recommendation, tile_state) do
    recommendation_id = Map.get(recommendation, :recommendation_id)

    is_binary(recommendation_id) and recommendation_id != "" and
      tile_state.last_recommendation_id == recommendation_id and
      tile_state.submitted_sentiment in [:up, :down]
  end

  defp default_recommendation do
    %{
      label: "AI Recommendation",
      status: :unavailable,
      recommendation_id: nil,
      body: nil,
      aria_label: "AI Recommendation",
      can_regenerate?: false,
      can_submit_sentiment?: false
    }
  end

  defp summary_scope_copy(nil, course_title)
       when is_binary(course_title) and course_title != "" do
    "Scoped overview for #{course_title}."
  end

  defp summary_scope_copy(scope_label, _course_title)
       when is_binary(scope_label) and scope_label != "" do
    "Scoped overview for #{scope_label}."
  end

  defp summary_scope_copy(_scope_label, _course_title),
    do: "Scoped overview for the current selection."

  defp status_badge(%{status: :ready}), do: "Ready"
  defp status_badge(%{status: :partial}), do: "Partial"
  defp status_badge(%{status: :loading}), do: "Loading"
  defp status_badge(%{status: :unavailable}), do: "Unavailable"
  defp status_badge(_), do: "Loading"

  defp row_grid_classes(%{visible_card_count: 1}),
    do: "grid-cols-1 lg:grid-cols-[213px_minmax(0,1fr)]"

  defp row_grid_classes(%{visible_card_count: 2}),
    do: "grid-cols-1 md:grid-cols-2 lg:grid-cols-[213px_213px_minmax(0,1fr)]"

  defp row_grid_classes(%{visible_card_count: 3}),
    do: "grid-cols-1 md:grid-cols-2 lg:grid-cols-[213px_213px_213px_minmax(0,1fr)]"

  defp row_grid_classes(_), do: "grid-cols-1 lg:grid-cols-[213px_minmax(0,1fr)]"

  defp card_title_line_one("Average " <> _rest), do: "Average"
  defp card_title_line_one(label), do: label

  defp card_title_line_two("Average " <> rest), do: rest
  defp card_title_line_two(_label), do: ""

  defp tooltip_copy(key), do: Map.get(@tooltip_copy, key, "Definition unavailable.")

  defp recommendation_body(%{status: :thinking}) do
    "Generating a scoped recommendation for this selection."
  end

  defp recommendation_body(%{status: :beginning_course, body: body})
       when is_binary(body) and body != "" do
    body
  end

  defp recommendation_body(%{status: :beginning_course}) do
    "Students have not generated enough activity in this scope yet. A recommendation will appear once meaningful work is available."
  end

  defp recommendation_body(%{status: :ready, body: body}) when is_binary(body) and body != "" do
    body
  end

  defp recommendation_body(%{status: :unavailable}) do
    "A scoped recommendation is not available for this selection yet."
  end

  defp recommendation_body(%{body: body}) when is_binary(body) and body != "" do
    body
  end

  defp recommendation_body(_),
    do: "A scoped recommendation is not available for this selection yet."

  defp recommendation_status_label(:ready), do: "Ready"
  defp recommendation_status_label(:thinking), do: "Thinking"
  defp recommendation_status_label(:beginning_course), do: "Starting"
  defp recommendation_status_label(:unavailable), do: "Unavailable"
  defp recommendation_status_label(_), do: "Unavailable"
end

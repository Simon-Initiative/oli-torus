defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile do
  @moduledoc """
  Summary tile surface for `MER-5249`.
  """

  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

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
     |> assign(
       :recommendation,
       normalize_recommendation(Map.get(projection, :recommendation, default_recommendation()))
     )
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
            aria-label={recommendation_aria_label(@recommendation)}
            aria-busy={recommendation_busy?(@recommendation, @projection_status, @tile_state)}
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
                {recommendation_label(@recommendation)}
              </h4>
            </div>

            <div class="flex flex-1 flex-col pl-[33px] pr-[28px]">
              <p class="mt-[6px] max-w-[41.4375rem] text-base leading-6 text-Text-text-high">
                {recommendation_body(@recommendation, @projection_status, @tile_state)}
              </p>

              <div class="mt-auto flex items-center justify-end gap-[10px] pt-3 pb-[10px] pr-[10px] text-Icon-icon-default">
                <%= if recommendation_thinking?(@recommendation, @tile_state) do %>
                  <span
                    class="inline-flex items-center gap-2 text-sm font-medium leading-4 text-Text-text-high"
                    role="status"
                    aria-live="polite"
                  >
                    <Icons.ai_spinner class="h-[28px] w-[28px]" />
                    <span>Thinking...</span>
                  </span>
                <% else %>
                  <%= if show_additional_feedback_button?(@recommendation, @tile_state) do %>
                    <Button.button
                      variant={:text}
                      size={:sm}
                      phx-click={
                        Modal.show_modal(
                          JS.push("summary_recommendation_additional_feedback_opened",
                            value: %{recommendation_id: recommendation_id(@recommendation)}
                          ),
                          "summary_recommendation_additional_feedback_modal_#{@id}"
                        )
                      }
                      aria-label="Additional feedback"
                      class="mr-10 h-auto cursor-pointer px-0 py-0 font-open-sans text-sm font-semibold leading-4 text-Text-text-button hover:text-Text-text-button hover:no-underline disabled:cursor-not-allowed"
                    >
                      Additional feedback
                    </Button.button>
                  <% else %>
                    <%= if additional_feedback_submitted?(@recommendation, @tile_state) do %>
                      <span class="text-sm font-semibold leading-4 text-Text-text-low">
                        Additional feedback submitted
                      </span>
                    <% else %>
                      <div class="group relative inline-flex">
                        <button
                          type="button"
                          phx-click="summary_recommendation_sentiment_submitted"
                          phx-value-recommendation_id={recommendation_id(@recommendation)}
                          phx-value-sentiment="up"
                          aria-label="Good recommendation"
                          aria-describedby={"summary-recommendation-tooltip-up-#{@id}"}
                          disabled={sentiment_disabled?(@recommendation, @tile_state)}
                          class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-default disabled:opacity-60"
                        >
                          <Icons.thumbs_up_ai class="stroke-current" />
                        </button>
                        <div
                          id={"summary-recommendation-tooltip-up-#{@id}"}
                          role="tooltip"
                          class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 z-20 hidden -translate-x-1/2 whitespace-nowrap rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block"
                        >
                          Good recommendation
                        </div>
                      </div>
                      <div class="group relative inline-flex">
                        <button
                          type="button"
                          phx-click="summary_recommendation_sentiment_submitted"
                          phx-value-recommendation_id={recommendation_id(@recommendation)}
                          phx-value-sentiment="down"
                          aria-label="Bad recommendation"
                          aria-describedby={"summary-recommendation-tooltip-down-#{@id}"}
                          disabled={sentiment_disabled?(@recommendation, @tile_state)}
                          class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-default disabled:opacity-60"
                        >
                          <Icons.thumbs_down_ai class="stroke-current" />
                        </button>
                        <div
                          id={"summary-recommendation-tooltip-down-#{@id}"}
                          role="tooltip"
                          class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 z-20 hidden -translate-x-1/2 whitespace-nowrap rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block"
                        >
                          Bad recommendation
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                  <div class="group relative inline-flex">
                    <button
                      type="button"
                      phx-click="summary_recommendation_regenerate"
                      phx-value-recommendation_id={recommendation_id(@recommendation)}
                      aria-label="Regenerate recommendation"
                      aria-describedby={"summary-recommendation-tooltip-regenerate-#{@id}"}
                      disabled={
                        recommendation_busy?(@recommendation, @projection_status, @tile_state) or
                          !Map.get(@recommendation, :can_regenerate?, false)
                      }
                      class="inline-flex h-6 w-6 items-center justify-center transition hover:text-Text-text-high disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      <Icons.regenerate_ai class="stroke-current" />
                    </button>
                    <div
                      id={"summary-recommendation-tooltip-regenerate-#{@id}"}
                      role="tooltip"
                      class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 z-20 hidden -translate-x-1/2 whitespace-nowrap rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block"
                    >
                      Regenerate recommendation
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </section>

      <.additional_feedback_modal
        recommendation={@recommendation}
        tile_state={@tile_state}
        modal_dom_id={"summary_recommendation_additional_feedback_modal_#{@id}"}
      />
    </article>
    """
  end

  defp default_tile_state do
    %{
      regenerate_in_flight?: false,
      submitted_sentiment: nil,
      last_recommendation_id: nil,
      show_additional_feedback_modal?: false,
      additional_feedback_text: "",
      additional_feedback_submitting?: false,
      additional_feedback_submitted?: false
    }
  end

  defp sentiment_disabled?(recommendation, tile_state) do
    not Map.get(recommendation, :can_submit_sentiment?, false) or
      tile_state.regenerate_in_flight? or
      sentiment_already_submitted?(recommendation, tile_state)
  end

  defp recommendation_busy?(recommendation, projection_status, tile_state) do
    tile_state.regenerate_in_flight? or
      recommendation_status(recommendation) == :thinking or
      (Map.get(projection_status, :status) in [:loading, :partial] and
         recommendation_status(recommendation) == :unavailable)
  end

  defp recommendation_thinking?(recommendation, tile_state) do
    recommendation_status(recommendation) == :thinking or tile_state.regenerate_in_flight?
  end

  defp sentiment_already_submitted?(recommendation, tile_state) do
    feedback_summary = Map.get(recommendation, :feedback_summary, %{})
    recommendation_id = Map.get(recommendation, :recommendation_id)

    persisted_sentiment? = Map.get(feedback_summary, :sentiment_submitted?, false)

    local_sentiment? =
      is_binary(recommendation_id) and recommendation_id != "" and
        tile_state.last_recommendation_id == recommendation_id and
        tile_state.submitted_sentiment in [:up, :down]

    persisted_sentiment? or local_sentiment?
  end

  defp show_additional_feedback_button?(recommendation, tile_state) do
    feedback_summary = Map.get(recommendation, :feedback_summary, %{})

    sentiment_already_submitted?(recommendation, tile_state) and
      not Map.get(feedback_summary, :additional_feedback_submitted?, false)
  end

  defp additional_feedback_submitted?(recommendation, tile_state) do
    feedback_summary = Map.get(recommendation, :feedback_summary, %{})

    sentiment_already_submitted?(recommendation, tile_state) and
      Map.get(feedback_summary, :additional_feedback_submitted?, false)
  end

  attr :recommendation, :map, required: true
  attr :tile_state, :map, required: true
  attr :modal_dom_id, :string, required: true

  defp additional_feedback_modal(assigns) do
    recommendation_id = recommendation_id(assigns.recommendation)
    feedback_text = Map.get(assigns.tile_state, :additional_feedback_text, "")
    show = Map.get(assigns.tile_state, :show_additional_feedback_modal?, false)
    submitted? = Map.get(assigns.tile_state, :additional_feedback_submitted?, false)
    submitting? = Map.get(assigns.tile_state, :additional_feedback_submitting?, false)

    assigns =
      assigns
      |> assign(:recommendation_id, recommendation_id)
      |> assign(:feedback_text, feedback_text)
      |> assign(:show, show)
      |> assign(:submitted?, submitted?)
      |> assign(:submitting?, submitting?)

    ~H"""
    <Modal.modal
      id={@modal_dom_id}
      wrapper_class="w-full p-4 sm:p-6"
      class="mx-auto max-w-[505px] rounded-[16px] border border-Border-border-default bg-Surface-surface-background shadow-[0px_2px_10px_0px_rgba(0,50,99,0.10)]"
      container_class="overflow-hidden bg-Surface-surface-background !ring-0 !ring-transparent !shadow-none"
      header_class="flex items-start justify-between bg-Surface-surface-background px-1 pb-0 pt-2"
      body_class="bg-Surface-surface-background px-1 pb-0 pt-2"
      title_class="text-[18px] font-semibold leading-6 text-Text-text-high"
      show={@show}
      show_close={false}
      on_cancel={
        Modal.hide_modal(
          JS.push("summary_recommendation_additional_feedback_cancelled"),
          @modal_dom_id
        )
      }
    >
      <:title>Provide Additional Feedback</:title>
      <:header_actions>
        <Button.button
          variant={:close}
          aria-label="Close additional feedback modal"
          phx-click={
            Modal.hide_modal(
              JS.push("summary_recommendation_additional_feedback_cancelled"),
              @modal_dom_id
            )
          }
        />
      </:header_actions>

      <%= if @submitted? do %>
        <div class="flex items-center gap-2 pb-2 mt-3">
          <Icons.checkmark class="h-4 w-4 text-[#00E28D]" />
          <p class="font-open-sans text-base font-normal leading-6 text-Text-text-high">
            Thank you for your feedback!
          </p>
        </div>
      <% else %>
        <form
          id={"summary-recommendation-additional-feedback-form-#{@modal_dom_id}"}
          phx-change="summary_recommendation_additional_feedback_changed"
          phx-submit="summary_recommendation_additional_feedback_submitted"
          class="space-y-4"
        >
          <input type="hidden" name="recommendation_id" value={@recommendation_id} />
          <p class="font-open-sans text-base font-normal leading-6 text-Text-text-high">
            We use this feedback to improve our AI features.
          </p>
          <div class="rounded-[12px] border border-Border-border-subtle bg-Surface-surface-primary p-2 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]">
            <textarea
              id={"summary-recommendation-additional-feedback-textarea-#{@modal_dom_id}"}
              name="feedback_text"
              rows="4"
              class="h-[121px] w-full resize-none rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-4 py-3 font-open-sans text-sm font-normal leading-6 text-Text-text-high outline-none placeholder:text-Text-text-high focus:border-Border-border-default focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
              placeholder="A short description of your experience"
            ><%= @feedback_text %></textarea>
          </div>
        </form>
      <% end %>

      <:custom_footer>
        <%= if @submitted? do %>
          <div class="bg-Surface-surface-background px-6 pb-4 pt-3" />
        <% else %>
          <div class="bg-Surface-surface-background px-6 pb-6 pt-4">
            <div class="flex items-center justify-end">
              <Button.button
                variant={:primary}
                size={:sm}
                type="submit"
                form={"summary-recommendation-additional-feedback-form-#{@modal_dom_id}"}
                phx-disable-with="Submitting..."
                disabled={@submitting? or String.trim(@feedback_text) == ""}
                class="bg-Fill-Buttons-fill-primary text-Text-text-white disabled:bg-Fill-Buttons-fill-primary disabled:text-Text-text-white disabled:opacity-60"
              >
                Submit
              </Button.button>
            </div>
          </div>
        <% end %>
      </:custom_footer>
    </Modal.modal>
    """
  end

  defp default_recommendation do
    %{
      label: "AI Recommendation",
      status: :unavailable,
      generation_mode: nil,
      recommendation_id: nil,
      body: nil,
      aria_label: "AI Recommendation",
      can_regenerate?: false,
      can_submit_sentiment?: false
    }
  end

  defp normalize_recommendation(%{label: _, status: _, recommendation_id: _} = recommendation),
    do: Map.merge(default_recommendation(), recommendation)

  defp normalize_recommendation(%{} = recommendation) do
    body =
      Map.get(recommendation, :body) ||
        Map.get(recommendation, :message) ||
        Map.get(recommendation, :text)

    status =
      recommendation
      |> Map.get(:status, Map.get(recommendation, :state, :unavailable))
      |> normalize_recommendation_status()

    generation_mode = Map.get(recommendation, :generation_mode, Map.get(recommendation, :mode))

    recommendation_id =
      recommendation
      |> Map.get(:recommendation_id, Map.get(recommendation, :id))
      |> normalize_recommendation_id()

    sentiment_submitted? =
      recommendation
      |> Map.get(:feedback_summary, %{})
      |> Map.get(:sentiment_submitted?, false)

    feedback_summary = Map.get(recommendation, :feedback_summary, %{})

    %{
      label: Map.get(recommendation, :label, "AI Recommendation"),
      status: status,
      generation_mode: generation_mode,
      recommendation_id: recommendation_id,
      body: body,
      feedback_summary: feedback_summary,
      aria_label:
        recommendation_aria_label(%{body: body, label: Map.get(recommendation, :label)}),
      can_regenerate?:
        Map.get(recommendation, :can_regenerate?, status in [:ready, :beginning_course]),
      can_submit_sentiment?:
        Map.get(
          recommendation,
          :can_submit_sentiment?,
          status in [:ready, :beginning_course] and not sentiment_submitted? and
            is_binary(recommendation_id)
        )
    }
  end

  defp normalize_recommendation(other), do: other

  defp normalize_recommendation_status(status) when status in [:ready, :thinking, :unavailable],
    do: status

  defp normalize_recommendation_status(:generating), do: :thinking
  defp normalize_recommendation_status(:no_signal), do: :beginning_course
  defp normalize_recommendation_status(:fallback), do: :ready
  defp normalize_recommendation_status(:expired), do: :unavailable

  defp normalize_recommendation_status(status)
       when status in [:beginning_course, :beginning_course_state],
       do: :beginning_course

  defp normalize_recommendation_status(status) when is_binary(status) do
    case String.downcase(status) do
      "thinking" -> :thinking
      "generating" -> :thinking
      "beginning_course" -> :beginning_course
      "beginning_course_state" -> :beginning_course
      "no_signal" -> :beginning_course
      "fallback" -> :ready
      "unavailable" -> :unavailable
      "expired" -> :unavailable
      _ -> :ready
    end
  end

  defp normalize_recommendation_status(_status), do: :ready

  defp normalize_recommendation_id(recommendation_id)
       when is_integer(recommendation_id) and recommendation_id > 0,
       do: Integer.to_string(recommendation_id)

  defp normalize_recommendation_id(recommendation_id)
       when is_binary(recommendation_id) and recommendation_id != "",
       do: recommendation_id

  defp normalize_recommendation_id(_recommendation_id), do: nil

  defp recommendation_label(%{label: label}) when is_binary(label) and label != "", do: label
  defp recommendation_label(_), do: "AI Recommendation"

  defp recommendation_aria_label(%{aria_label: aria_label})
       when is_binary(aria_label) and aria_label != "",
       do: aria_label

  defp recommendation_aria_label(%{body: body}) when is_binary(body) and body != "" do
    "AI Recommendation: #{body}"
  end

  defp recommendation_aria_label(%{label: label}) when is_binary(label) and label != "",
    do: label

  defp recommendation_aria_label(_), do: "AI Recommendation"

  defp recommendation_status(%{status: status}), do: status
  defp recommendation_status(%{state: state}), do: normalize_recommendation_status(state)
  defp recommendation_status(_), do: :unavailable

  defp recommendation_id(%{recommendation_id: recommendation_id}),
    do: recommendation_id

  defp recommendation_id(%{id: id}), do: normalize_recommendation_id(id)
  defp recommendation_id(_), do: nil

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

  defp recommendation_body(recommendation, projection_status, tile_state) do
    case recommendation_display_state(recommendation, projection_status, tile_state) do
      :loading ->
        "Generating a scoped recommendation for this selection."

      :regenerating ->
        # Keep the previous recommendation body visible while regenerating.
        recommendation_body_during_regeneration(recommendation)

      :beginning_course ->
        "Students have not generated enough activity in this scope yet. A recommendation will appear once meaningful work is available."

      :ready ->
        recommendation_body(recommendation)

      :unavailable ->
        "A scoped recommendation is not available for this selection yet."
    end
  end

  defp recommendation_body_during_regeneration(%{body: body})
       when is_binary(body) and body != "" do
    body
  end

  defp recommendation_body_during_regeneration(%{message: message})
       when is_binary(message) and message != "" do
    message
  end

  defp recommendation_body_during_regeneration(recommendation),
    do: recommendation_body(recommendation)

  defp recommendation_display_state(recommendation, projection_status, tile_state) do
    cond do
      tile_state.regenerate_in_flight? ->
        :regenerating

      recommendation_status(recommendation) == :thinking ->
        :loading

      Map.get(projection_status, :status) in [:loading, :partial] and
          recommendation_status(recommendation) == :unavailable ->
        :loading

      recommendation_status(recommendation) == :beginning_course ->
        :beginning_course

      recommendation_status(recommendation) == :ready ->
        :ready

      true ->
        :unavailable
    end
  end
end

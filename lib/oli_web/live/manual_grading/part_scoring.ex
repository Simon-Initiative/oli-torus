defmodule OliWeb.ManualGrading.PartScoring do
  use OliWeb, :html

  alias OliWeb.Common.Utils
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.ManualGrading.ScoreFeedback

  attr :part_attempt, :any, required: true
  attr :part_scoring, :any, required: true
  attr :feedback_changed, :any, required: true
  attr :score_changed, :any, required: true
  attr :input_type_label, :string, default: "Input"
  attr :selected, :boolean, default: false
  attr :selected_changed, :string, required: true
  attr :feedback_required, :boolean, default: false

  def render(%{part_attempt: %{grading_approach: :automatic}} = assigns) do
    assigns =
      assigns
      |> assign_default_part_scoring()
      |> assign(:automatic_feedback_text, automatic_feedback_text(assigns.part_attempt))

    ~H"""
    <form phx-submit="prevent_default">
      <div
        class={card_classes(@selected)}
        role="button"
        tabindex="0"
        aria-pressed={to_string(@selected)}
        phx-click={@selected_changed}
        phx-keydown={@selected_changed}
        phx-value-attempt_guid={@part_attempt.attempt_guid}
        phx-value-part_id={@part_attempt.part_id}
      >
        <div class="mb-3 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <div class="text-sm font-semibold text-Text-text-high">Automatically Graded</div>
              <span class={input_type_badge_classes()}>{@input_type_label}</span>
              <span :if={@selected} class={selected_badge_classes()}>Selected Input</span>
              <span :if={!@selected} class={selection_hint_classes()}>Click to inspect</span>
            </div>
            <div class="text-sm text-Text-text-low">
              This input was scored by the system and is read only here.
            </div>
          </div>
          <div class="text-sm text-Text-text-low md:text-right">
            Score: {readonly_value(@part_attempt.score || @part_scoring.score, "Pending")} / {readonly_value(
              @part_attempt.out_of || @part_scoring.out_of
            )}
          </div>
        </div>

        <div class="min-w-0">
          <div class="w-full">
            <label class={field_label_classes()}>Feedback</label>
            {feedback(assigns)}
          </div>
        </div>
      </div>
    </form>
    """
  end

  def render(%{part_attempt: %{lifecycle_state: :evaluated}} = assigns) do
    assigns = assign_default_part_scoring(assigns)

    ~H"""
    <form phx-submit="prevent_default">
      <div
        class={card_classes(@selected)}
        role="button"
        tabindex="0"
        aria-pressed={to_string(@selected)}
        phx-click={@selected_changed}
        phx-keydown={@selected_changed}
        phx-value-attempt_guid={@part_attempt.attempt_guid}
        phx-value-part_id={@part_attempt.part_id}
      >
        <div class="mb-3 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
          <div class="flex flex-wrap items-center gap-2">
            <div class="text-sm font-semibold text-Text-text-high">Evaluated</div>
            <span class={input_type_badge_classes()}>{@input_type_label}</span>
            <span :if={@selected} class={selected_badge_classes()}>Selected Input</span>
            <span :if={!@selected} class={selection_hint_classes()}>Click to inspect</span>
          </div>
          <div class="text-sm text-Text-text-low md:text-right">
            Score: {readonly_value(@part_attempt.score)} / {readonly_value(@part_attempt.out_of)}
          </div>
        </div>

        <div class="min-w-0">
          <div class="w-full">
            <label class={field_label_classes()}>Feedback</label>
            {feedback(assigns)}
          </div>
        </div>
      </div>
    </form>
    """
  end

  def render(assigns) do
    assigns = assign_default_part_scoring(assigns)

    ~H"""
    <form phx-submit="prevent_default">
      <div
        class={card_classes(@selected)}
        role="button"
        tabindex="0"
        aria-pressed={to_string(@selected)}
        phx-click={@selected_changed}
        phx-keydown={@selected_changed}
        phx-value-attempt_guid={@part_attempt.attempt_guid}
        phx-value-part_id={@part_attempt.part_id}
      >
        <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div class="flex flex-wrap items-center gap-2">
            <div class="text-sm font-semibold text-Text-text-high">Manual Grading</div>
            <span class={input_type_badge_classes()}>{@input_type_label}</span>
            <span :if={@selected} class={selected_badge_classes()}>Selected Input</span>
            <span :if={!@selected} class={selection_hint_classes()}>Click to inspect</span>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-4 md:grid-cols-[14rem_minmax(0,1fr)] md:items-start">
          <div class="w-full space-y-3 md:max-w-[14rem]">
            <div>
              <label
                for={"score_" <> @part_attempt.attempt_guid}
                class={field_label_classes()}
              >
                Score
              </label>
              <input
                id={"score_" <> @part_attempt.attempt_guid}
                phx-hook="ManualGradingScoreInput"
                phx-value-change={@score_changed}
                type="number"
                class={input_classes()}
                step="any"
                min="0"
                max={@part_scoring.out_of}
                value={@part_scoring.score}
              />
            </div>

            <div>
              <label
                for={"out_of_" <> @part_attempt.attempt_guid}
                class={field_label_classes()}
              >
                Out Of
              </label>
              <input
                id={"out_of_" <> @part_attempt.attempt_guid}
                type="text"
                readonly
                aria-readonly="true"
                class={readonly_input_classes()}
                value={@part_scoring.out_of}
              />
            </div>

            <div class="grid grid-cols-3 gap-2" role="group" aria-label="Scoring shortcut group">
              <Button.button
                variant={:secondary}
                size={:sm}
                width="w-full"
                class="px-0"
                phx-click={@score_changed}
                phx-value-id={"score_" <> @part_attempt.attempt_guid}
                phx-value-score={0}
              >
                0%
              </Button.button>
              <Button.button
                variant={:secondary}
                size={:sm}
                width="w-full"
                class="px-0"
                phx-click={@score_changed}
                phx-value-id={"score_" <> @part_attempt.attempt_guid}
                phx-value-score={@part_scoring.out_of / 2}
              >
                50%
              </Button.button>
              <Button.button
                variant={:secondary}
                size={:sm}
                width="w-full"
                class="px-0"
                phx-click={@score_changed}
                phx-value-id={"score_" <> @part_attempt.attempt_guid}
                phx-value-score={@part_scoring.out_of}
              >
                100%
              </Button.button>
            </div>
          </div>

          <div class="min-w-0">
            <label
              for={"feedback_" <> @part_attempt.attempt_guid}
              class={field_label_classes()}
            >
              <span>Feedback</span>
              <span class="ml-2 text-xs font-semibold uppercase tracking-wide text-Text-text-low">
                Required
              </span>
            </label>
            <textarea
              id={"feedback_" <> @part_attempt.attempt_guid}
              phx-hook="TextInputListener"
              phx-value-change={@feedback_changed}
              class={textarea_classes()}
              placeholder="Enter feedback for the student..."
              autocomplete="on"
              wrap="soft"
              maxlength="2000"
              rows="6"
              required
              aria-required="true"
              aria-invalid={to_string(@feedback_required)}
              aria-describedby={
                Enum.join(
                  [
                    "feedback_help_" <> @part_attempt.attempt_guid,
                    @feedback_required && "feedback_error_" <> @part_attempt.attempt_guid
                  ]
                  |> Enum.reject(&is_nil/1),
                  " "
                )
              }
            ><%= @part_scoring.feedback %></textarea>
            <p
              id={"feedback_help_" <> @part_attempt.attempt_guid}
              class="mt-2 text-xs text-Text-text-low"
            >
              Feedback is required before you can apply grading for this activity.
            </p>
            <p
              :if={@feedback_required}
              id={"feedback_error_" <> @part_attempt.attempt_guid}
              class="mt-2 text-xs font-medium text-Text-text-error"
            >
              Add feedback for this input to enable Apply Score and Feedback.
            </p>
          </div>
        </div>
      </div>
    </form>
    """
  end

  defp feedback(%{part_attempt: %{grading_approach: :automatic}} = assigns) do
    ~H"""
    <div class={feedback_panel_classes()}>
      {@automatic_feedback_text}
    </div>
    """
  end

  defp feedback(assigns) do
    ~H"""
    <div class={feedback_panel_classes()}>
      {readonly_value(@part_scoring.feedback, "No feedback provided")}
    </div>
    """
  end

  defp assign_default_part_scoring(assigns) do
    assign(
      assigns,
      :part_scoring,
      Map.get(assigns, :part_scoring) || default_part_scoring(assigns)
    )
  end

  defp default_part_scoring(%{part_attempt: part_attempt}) do
    %ScoreFeedback{
      score: nil,
      feedback: nil,
      out_of: Map.get(part_attempt, :out_of) || 1.0
    }
  end

  defp automatic_feedback_text(part_attempt) do
    part_attempt
    |> Utils.extract_from_part_attempt()
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
    |> case do
      "" -> "This part was automatically graded by the system"
      feedback -> feedback
    end
  end

  defp readonly_value(value, fallback \\ "")
  defp readonly_value(nil, fallback), do: fallback
  defp readonly_value(value, _fallback), do: value

  defp card_classes(true),
    do:
      "cursor-pointer rounded-xl border border-Border-border-bold bg-Surface-surface-secondary-hover px-4 py-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] ring-1 ring-Border-border-bold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-Border-border-bold focus-visible:ring-offset-2 focus-visible:ring-offset-Surface-surface-primary"

  defp card_classes(false),
    do:
      "cursor-pointer rounded-xl border border-Border-border-subtle bg-Surface-surface-secondary px-4 py-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] transition hover:border-Border-border-bold hover:bg-Surface-surface-secondary-hover hover:shadow-[0px_4px_14px_0px_rgba(0,50,99,0.08)] focus:outline-none focus-visible:ring-2 focus-visible:ring-Border-border-bold focus-visible:ring-offset-2 focus-visible:ring-offset-Surface-surface-primary"

  defp field_label_classes,
    do: "mb-2 block text-sm font-semibold text-Text-text-high"

  defp selected_badge_classes,
    do:
      "inline-flex items-center rounded-full border border-Fill-Accent-fill-accent-blue-bold bg-Fill-Accent-fill-accent-blue-bold px-2.5 py-1 text-xs font-semibold text-Text-text-white shadow-[0px_1px_4px_0px_rgba(0,50,99,0.18)]"

  defp selection_hint_classes,
    do:
      "inline-flex items-center rounded-full bg-Surface-surface-primary px-2.5 py-1 text-xs font-semibold text-Text-text-low"

  defp input_type_badge_classes,
    do:
      "inline-flex items-center rounded-full border border-Border-border-default bg-Surface-surface-primary px-2.5 py-1 text-xs font-semibold text-Text-text-high"

  defp input_classes,
    do:
      "block w-full rounded-lg border border-Border-border-default bg-Surface-surface-primary px-3 py-2 text-sm text-Text-text-high placeholder:text-Text-text-low shadow-none focus:border-Border-border-bold-hover focus:outline-none focus:ring-0"

  defp readonly_input_classes,
    do:
      "block w-full rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-3 py-2 text-sm text-Text-text-high shadow-none focus:outline-none focus:ring-0"

  defp textarea_classes,
    do:
      "block min-h-[10rem] w-full resize-y rounded-lg border border-Border-border-default bg-Surface-surface-primary px-3 py-3 text-sm text-Text-text-high placeholder:text-Text-text-low shadow-none focus:border-Border-border-bold-hover focus:outline-none focus:ring-0 aria-[invalid=true]:border-Border-border-error aria-[invalid=true]:ring-1 aria-[invalid=true]:ring-Border-border-error"

  defp feedback_panel_classes,
    do:
      "min-h-[4.5rem] rounded-lg border border-Border-border-subtle bg-Surface-surface-secondary-muted px-3 py-3 text-sm text-Text-text-high whitespace-pre-wrap break-words"
end

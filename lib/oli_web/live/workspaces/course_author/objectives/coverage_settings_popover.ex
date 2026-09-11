defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopover do
  @moduledoc """
  Presentation component for Coverage Issues threshold settings. It renders
  labelled formative and summative steppers, explanatory copy, and a restore
  action.

  `ObjectivesLive` owns threshold persistence and handles each action
  immediately. The Learn more affordance remains hidden and non-interactive.

  The caller owns open state and dismissal. This component is only rendered
  while open, so its keyboard handler cannot affect the surrounding page.
  """
  use Phoenix.Component

  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :trigger_id, :string, required: true
  attr :formative_threshold, :integer, required: true
  attr :summative_threshold, :integer, required: true

  def coverage_settings_popover(assigns) do
    ~H"""
    <div
      id={@id}
      class="absolute left-1/2 top-full z-10 mt-[11px] hidden w-[298px] -translate-x-1/2 flex-col rounded-[10px] border border-Border-border-default bg-Surface-surface-primary shadow-[0px_8px_14px_rgba(0,50,99,0.14)]"
      role="dialog"
      aria-label="Coverage issue thresholds"
      phx-mounted={open_js(@id, @trigger_id)}
      phx-window-keydown={close_js()}
      phx-key="Escape"
    >
      <.focus_wrap id={"#{@id}-focus-wrap"} class="flex flex-col">
        <div class="flex flex-col gap-3 px-4 pb-3 pt-4">
          <.coverage_threshold_row
            icon_bg_class="bg-Fill-Accent-fill-accent-blue"
            label="Minimum formative"
            value={@formative_threshold}
            decrement="decrement_coverage_formative_threshold"
            increment="increment_coverage_formative_threshold"
          >
            <Icons.clipboard
              variant="objective"
              width="11"
              height="13"
              class="text-Icon-icon-accent-blue"
            />
          </.coverage_threshold_row>

          <.coverage_threshold_row
            icon_bg_class="bg-Fill-Accent-fill-accent-orange"
            label="Minimum summative"
            value={@summative_threshold}
            decrement="decrement_coverage_summative_threshold"
            increment="increment_coverage_summative_threshold"
          >
            <span class="flex h-3 w-[11px] items-center justify-center">
              <Icons.assignments class="h-4 w-4 max-w-none shrink-0 stroke-Icon-icon-accent-orange" />
            </span>
          </.coverage_threshold_row>
        </div>

        <div class="border-t border-Border-border-default bg-Surface-surface-secondary px-4 pb-[10px] pt-[11px]">
          <p class="max-w-[254px] text-[11px] leading-[17px] text-Text-text-high">
            These thresholds determine which objectives are flagged as coverage issues. An objective is flagged when it has fewer formative or summative activities than the minimums set above.
          </p>
        </div>

        <div class="flex items-center justify-between border-t border-Border-border-default px-4 pb-[10px] pt-[11px]">
          <button
            type="button"
            phx-click="restore_default_coverage_thresholds"
            phx-keydown={close_js()}
            phx-key="Escape"
            class="rounded-md border border-Border-border-bold px-6 py-2 text-sm font-semibold leading-4 text-Specially-Tokens-Text-text-button-secondary shadow-[0px_2px_4px_0px_rgba(0,52,99,0.1)]"
          >
            Restore default
          </button>
          <span
            id="coverage-settings-learn-more"
            class="hidden py-1 text-sm font-bold leading-4 text-Text-text-button"
          >
            <%!-- Will be addressed on MER-5919, that is why we keep it hidden (but already styled to match Figma Design) --%>
            Learn more
          </span>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :icon_bg_class, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :decrement, :string, required: true
  attr :increment, :string, required: true
  slot :inner_block, required: true

  defp coverage_threshold_row(assigns) do
    ~H"""
    <div class="flex items-center">
      <div class="flex w-[177px] shrink-0 items-center gap-2">
        <div class={[
          "flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full",
          @icon_bg_class
        ]}>
          {render_slot(@inner_block)}
        </div>
        <span class="whitespace-nowrap text-[13px] font-semibold leading-[16.25px] text-Text-text-high">
          {@label}
        </span>
      </div>
      <.coverage_threshold_stepper
        label={String.downcase(@label)}
        value={@value}
        decrement={@decrement}
        increment={@increment}
      />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :decrement, :string, required: true
  attr :increment, :string, required: true

  defp coverage_threshold_stepper(assigns) do
    ~H"""
    <div class="flex h-[30px] w-[90px] shrink-0 items-center overflow-hidden rounded-md border border-Border-border-active">
      <button
        type="button"
        phx-click={@decrement}
        phx-keydown={close_js()}
        phx-key="Escape"
        disabled={@value <= 0}
        aria-label={"Decrease #{@label}"}
        class="flex h-[28px] w-[28px] items-center justify-center text-base leading-6 text-Text-text-high disabled:opacity-40"
      >
        &minus;
      </button>
      <span
        class="flex h-[28px] w-8 items-center justify-center border-x border-Border-border-active text-[13px] font-semibold leading-[19.5px] text-Text-text-high"
        aria-live="polite"
      >
        {@value}
      </span>
      <button
        type="button"
        phx-click={@increment}
        phx-keydown={close_js()}
        phx-key="Escape"
        aria-label={"Increase #{@label}"}
        class="flex h-[28px] w-[28px] items-center justify-center text-base leading-6 text-Text-text-high"
      >
        +
      </button>
    </div>
    """
  end

  @doc """
  Focuses an already-mounted settings popover.

  The trigger remains in the focus stack so keyboard dismissal can restore it.
  """
  @spec open_js(String.t(), String.t()) :: JS.t()
  def open_js(popover_id, trigger_id) do
    JS.push_focus(to: "##{trigger_id}")
    |> JS.show(
      to: "##{popover_id}",
      transition: {
        "ease-out duration-150 motion-reduce:duration-0",
        "opacity-0 scale-95 motion-reduce:scale-100",
        "opacity-100 scale-100"
      }
    )
    |> JS.focus_first(to: "##{popover_id}")
  end

  @doc """
  Restores focus to the trigger and asks the owning LiveView to unmount the popover.
  """
  @spec close_js() :: JS.t()
  def close_js do
    JS.pop_focus()
    |> JS.push("close_coverage_settings")
  end
end

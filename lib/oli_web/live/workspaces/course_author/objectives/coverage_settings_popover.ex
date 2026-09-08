defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageSettingsPopover do
  @moduledoc """
  Presentation component for Coverage Issues threshold settings. It renders
  labelled formative and summative steppers, explanatory copy, and a restore
  action.

  `ObjectivesLive` owns threshold persistence and handles each action
  immediately. The Learn more affordance remains hidden and non-interactive.

  The caller owns dismissal by placing `phx-click-away` on the wrapper that
  contains both the trigger and the popover.
  """
  use Phoenix.Component

  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :formative_threshold, :integer, required: true
  attr :summative_threshold, :integer, required: true

  def coverage_settings_popover(assigns) do
    ~H"""
    <div
      id={@id}
      class="absolute left-1/2 top-full z-10 mt-[11px] hidden w-[298px] -translate-x-1/2 flex-col rounded-[10px] border border-Border-border-default bg-Surface-surface-primary shadow-[0px_8px_14px_rgba(0,50,99,0.14)]"
      role="dialog"
      aria-label="Coverage issue thresholds"
    >
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
        aria-label={"Increase #{@label}"}
        class="flex h-[28px] w-[28px] items-center justify-center text-base leading-6 text-Text-text-high"
      >
        +
      </button>
    </div>
    """
  end

  @doc """
  Builds the `phx-click` JS command for the settings trigger button.

  Also flips the trigger's `aria-expanded` state.
  """
  @spec toggle_js(String.t(), String.t()) :: JS.t()
  def toggle_js(popover_id, trigger_id) do
    JS.toggle(
      to: "##{popover_id}",
      in: {"ease-out duration-150", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-out duration-100", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "##{trigger_id}")
  end

  @doc """
  Builds the `phx-click-away` JS command that closes the popover and resets its
  trigger. Idempotent, so it is safe to fire on clicks while already closed.

  Belongs on the wrapper enclosing both the trigger and the popover, so that
  clicking the trigger is never treated as a click away.
  """
  @spec close_js(String.t(), String.t()) :: JS.t()
  def close_js(popover_id, trigger_id) do
    JS.hide(
      to: "##{popover_id}",
      transition: {"ease-out duration-100", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
    |> JS.set_attribute({"aria-expanded", "false"}, to: "##{trigger_id}")
  end
end

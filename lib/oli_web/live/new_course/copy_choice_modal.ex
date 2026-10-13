defmodule OliWeb.Delivery.NewCourse.CopyChoiceModal do
  @moduledoc """
  The "Choose what to copy" modal shown when an instructor selects a My Course Sections
  source, matching Figma nodes 40:2695/40:2747 (light) and 40:2506/40:2623 (dark).
  """

  use OliWeb, :html

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons

  import OliWeb.Components.Modal

  attr :id, :string, default: "copy-choice-modal"
  attr :source_title, :string, default: nil
  attr :copy_scope, :atom, required: true, values: [:entire_course, :choose_what_to_copy]
  attr :copy_options, :map, required: true
  attr :loading, :boolean, default: false

  def render(assigns) do
    ~H"""
    <.modal
      id={@id}
      show={true}
      on_cancel={JS.push("cancel_copy_modal")}
      container_class="mx-auto w-full max-w-[620px] rounded-xl !bg-Background-bg-secondary"
      header_class="flex items-start justify-between px-8 pt-8"
      body_class="px-8 pb-9 pt-3 space-y-3"
      title_class="text-2xl font-bold text-Text-text-high"
    >
      <:title>Choose what to copy</:title>

      <p class="text-base text-Text-text-high">
        <span class="font-semibold">Creating new section from: </span>
        <span class="font-bold">{@source_title}</span>
      </p>

      <p class="text-sm leading-4 text-Text-text-high">
        This new section will be a stamp in time of the source at the moment you create it.
        Updates to the original section will not carry over to the new section.
      </p>

      <p class="pt-2 text-base font-semibold text-Text-text-high">What to copy</p>

      <div class="flex flex-col gap-3" role="radiogroup" aria-label="What to copy">
        <.copy_scope_radio
          value="entire_course"
          checked={@copy_scope == :entire_course}
          label="Copy entire course"
        />
        <.copy_scope_radio
          value="choose_what_to_copy"
          checked={@copy_scope == :choose_what_to_copy}
          label="Choose what to copy"
        />
      </div>

      <div class="flex w-full flex-col gap-1.5 rounded-md border border-Border-border-subtle bg-Surface-surface-secondary px-5 py-3">
        <.copy_group_checkbox
          label="Content / curriculum (Required)"
          group="content"
          checked={true}
          locked={true}
          muted={@copy_scope == :entire_course}
        />
        <.copy_group_checkbox
          label="Schedule"
          group="schedule"
          checked={Map.get(@copy_options, :schedule, false)}
          locked={false}
          muted={@copy_scope == :entire_course}
        />
        <.copy_group_checkbox
          label="Assessment settings (includes availability & due dates)"
          group="assessment_settings"
          checked={Map.get(@copy_options, :assessment_settings, false)}
          locked={false}
          muted={@copy_scope == :entire_course}
        />
        <.copy_group_checkbox
          label="Course features (AI Assistant, Notes, Course Discussions)"
          group="course_features"
          checked={Map.get(@copy_options, :section_settings, false)}
          locked={false}
          muted={@copy_scope == :entire_course}
        />
      </div>

      <div class="flex w-full items-center justify-end gap-2 pt-4">
        <Button.button variant={:secondary} size={:sm} phx-click="cancel_copy_modal">
          Cancel
        </Button.button>
        <Button.button
          variant={:primary}
          size={:sm}
          disabled={@loading}
          phx-click="confirm_copy_modal"
        >
          Create Section
        </Button.button>
      </div>
    </.modal>
    """
  end

  attr :value, :string, required: true
  attr :checked, :boolean, required: true
  attr :label, :string, required: true

  defp copy_scope_radio(assigns) do
    ~H"""
    <label class="flex cursor-pointer items-start gap-3">
      <input
        type="radio"
        name="copy_scope"
        value={@value}
        checked={@checked}
        phx-click="set_copy_scope"
        phx-value-scope={@value}
        class="peer sr-only"
      />
      <span
        aria-hidden="true"
        class={[
          "mt-1 h-4 w-4 shrink-0 rounded-full border transition",
          "peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2",
          if(@checked,
            do: "border-Border-border-bold bg-Fill-Buttons-fill-primary",
            else: "border-Border-border-active bg-transparent"
          )
        ]}
      />
      <span class="text-base text-Text-text-high">{@label}</span>
    </label>
    """
  end

  attr :label, :string, required: true

  attr :group, :string,
    required: true,
    values: ["content", "schedule", "assessment_settings", "course_features"]

  attr :checked, :boolean, required: true
  attr :locked, :boolean, required: true
  attr :muted, :boolean, required: true

  defp copy_group_checkbox(assigns) do
    assigns = assign(assigns, :disabled, assigns.locked or assigns.muted)

    ~H"""
    <label class={[
      "flex items-center gap-1.5",
      if(@disabled, do: "cursor-default", else: "cursor-pointer")
    ]}>
      <input
        type="checkbox"
        name={"copy_group_#{@group}"}
        checked={@checked and not @muted}
        disabled={@disabled}
        phx-click={if !@disabled, do: "toggle_copy_group"}
        phx-value-group={@group}
        class="peer sr-only"
      />
      <span
        aria-hidden="true"
        class={[
          "relative flex h-4 w-4 shrink-0 items-center justify-center rounded-sm border transition",
          "peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2",
          checkbox_indicator_class(@muted, @checked)
        ]}
      >
        <Icons.checkmark :if={@checked and not @muted} class="h-2.5 w-2.5 text-Text-text-white" />
      </span>
      <span class={[
        "text-base",
        if(@muted, do: "text-Text-text-low-alpha", else: "text-Text-text-high")
      ]}>
        {@label}
      </span>
    </label>
    """
  end

  defp checkbox_indicator_class(true = _muted, _checked),
    do: "border-Text-text-low-alpha bg-transparent"

  defp checkbox_indicator_class(false = _muted, true = _checked),
    do: "border-Fill-Buttons-fill-primary bg-Fill-Buttons-fill-primary"

  defp checkbox_indicator_class(false = _muted, false = _checked),
    do: "border-Border-border-active bg-transparent"
end

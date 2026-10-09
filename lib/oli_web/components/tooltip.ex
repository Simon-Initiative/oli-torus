defmodule OliWeb.Components.Tooltip do
  @moduledoc """
  HTML tooltips and popovers whose content remains in the LiveView-owned DOM.

  Use `render/1` with `trigger` and `content` slots. The component generates the
  help button, accessible relationships and positioning attributes; callers own
  the content and appearance. Alias `OliWeb.Components.Tooltip` and `OliWeb.Icons`
  in the caller to use the component and the info icon shown in the examples.

  Choose the mode by the kind of content:

  * `:tooltip` (default) for explanatory text or non-interactive images. Opens
    with hover or keyboard focus and uses `role="tooltip"`.
  * `:popover` for links, buttons or other interactive content. Opens with click
    or keyboard activation and uses `role="dialog"`.

  Slots are not inspected or restricted. A link technically works in tooltip
  mode, but interactive content does not match its accessibility semantics;
  use popover mode for those cases. Popover mode currently has no hover option.

  `render/1` uses the existing `Popover` hook in an opt-in mode. Other callers of
  that hook and `GlobalTooltip` retain their existing contracts.
  """

  use Phoenix.Component

  attr :id, :string, required: true, doc: "Stable, page-unique component id."
  attr :trigger_id, :string, default: nil, doc: "Button id; defaults to <id>-trigger."
  attr :label, :string, required: true, doc: "Accessible button name and popover dialog label."

  attr :mode, :atom,
    default: :tooltip,
    values: [:tooltip, :popover],
    doc: "Hover/focus tooltip or click-activated interactive popover."

  attr :position, :string,
    default: "top",
    values: ["top", "bottom"],
    doc: "Preferred side; may flip to fit available space."

  attr :align, :string,
    default: "center",
    values: ["left", "center", "right"],
    doc: "Preferred alignment with the button; may shift to fit."

  attr :offset, :integer, default: 4, doc: "Nonnegative gap from the button, in pixels."

  attr :arrow, :boolean,
    default: false,
    doc: "Show a decorative arrow pointing toward the button."

  attr :class, :string, default: nil, doc: "Replaces default bubble classes when supplied."

  attr :trigger_class, :string,
    default:
      "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
    doc: "Button classes; replaces the default visible keyboard focus outline."

  slot :trigger,
    required: true,
    doc: "Button content, such as text or an icon; do not nest a button."

  slot :content,
    required: true,
    doc: "Bubble content rendered in place, without copying or moving it."

  @doc """
  Renders a help button and a tooltip or interactive popover from HEEx slots.

  ## Opening, moving the pointer and closing

  In `:tooltip` mode, hover or focus opens the bubble. Leaving the button starts
  a 120 ms close timer. Entering the bubble before it expires cancels the timer,
  so it remains open while the pointer is over the content. Leaving both starts
  the timer again; it closes only when neither is hovered and focus is outside
  the component. Focus on the button also keeps the bubble open.

  The 120 ms delay is fixed, not a component option. Crossing the gap too slowly
  can close the bubble before the pointer reaches it, especially with a large
  `offset`. The trigger also supports click activation/toggling, with a brief
  guard against immediately closing a bubble just opened by hover or focus.

  In `:popover` mode, click or keyboard activation toggles the bubble; hover and
  focus alone do not open it, and leaving it with the pointer does not close it.
  Tab follows the normal order through links and controls. Content clicks keep
  it open unless an element has `data-dismiss-tooltip`.

  Both modes close on Escape or an outside click. Escape from inside the content,
  or a `data-dismiss-tooltip` control, restores focus to the trigger. In tooltip
  mode, restoring focus during dismissal does not reopen the bubble. A subsequent
  focus, hover or activation can open it again. Opening another instance closes
  the previous tooltip. Keyboard focus opens tooltip mode without moving focus
  into the content; this lets keyboard users discover the same help as hover users.

  ## Content and LiveView

  `trigger` supplies the content of a generated button, not the button itself.
  `content` accepts text and HTML, including images, links and LiveView event
  handlers. Use popover mode for interactive content. The root and bubble are
  `div` elements, so content may include block layouts such as `div`, `p`, lists
  and forms as well as text and images. Place the component in a container that
  accepts flow content (for example, a `div`), not inside a paragraph, `span`,
  button or link. Its `inline-flex` root can sit alongside a label in a flex row.

  Slot nodes stay under the component in the LiveView-owned DOM. They are not
  cloned or moved to `document.body`; event handlers and updates keep working.
  Keep `id` stable and unique across the page. The bubble id is `<id>-content`.
  In a LiveComponent, add `phx-target={@myself}` to slot controls when their
  events should be handled by that component rather than the parent LiveView.

  ## Appearance and positioning

  Omitting `class` uses the default help-text appearance: left-aligned small
  text, normal weight, semantic background/text/border colors, padding, rounded
  corners and a shadow, with a preferred width between 210 and 260 px.
  Supplying `class` replaces those classes entirely, so include all desired
  typography, colors, border, spacing and width. The generated button has a visible
  `focus-visible` outline by default. `trigger_class` independently replaces its
  classes; include a visible keyboard focus style when supplying custom classes.
  `arrow={true}` adds a decorative arrow; the default is `false`. It follows the
  actual placement after flips and shifts, and uses the bubble's computed solid
  background and border colors. With an arrow, the styled bubble is wrapped in
  a positioning container so scrolling content does not clip the arrow.

  Position and alignment are preferences. The hook flips/shifts the bubble to
  fit the viewport with an 8 px margin, caps dimensions, wraps long text and
  allows tall content to scroll. It repositions on scroll, resize, LiveView
  updates and observed element size changes. The fixed positioning and viewport
  constraints apply even when custom classes are supplied.

  Modern browsers use the native top layer without ancestor overflow clipping.
  Browsers without native popover support position the content in place and
  remain subject to ancestor clipping. Hook positioning requires JavaScript;
  the bubble is initially hidden.

  ## Text only

      <Tooltip.render id="metric-help" label="Metric definition" position="bottom">
        <:trigger><Icons.info /></:trigger>
        <:content>How this metric is calculated.</:content>
      </Tooltip.render>

  ## Formatted text and an image

      <Tooltip.render id="chart-help" label="How to read the chart">
        <:trigger><Icons.info /></:trigger>
        <:content>
          <strong>The dashed line</strong> represents the scheduled progress.
          <img
            src="/images/progress-example.png"
            alt="Example chart with a dashed schedule line"
            class="mt-2 block max-w-full"
          />
        </:content>
      </Tooltip.render>

  The image URL is illustrative; use an existing asset and descriptive alt text.

  ## Optional arrow

      <Tooltip.render id="metric-arrow-help" label="Metric definition" arrow={true}>
        <:trigger><Icons.info /></:trigger>
        <:content>How this metric is calculated.</:content>
      </Tooltip.render>

  The option works in either mode. Omit it to keep the bubble without an arrow.

  ## Text and a link

      <Tooltip.render id="score-help" label="Assessment score information" mode={:popover}>
        <:trigger>About scores</:trigger>
        <:content>
          <div class="flex flex-col gap-2">
            <p>Scores summarize submitted assessments.</p>
            <a href="/help/assessment-scores" class="underline">Read how scores are calculated</a>
          </div>
        </:content>
      </Tooltip.render>

  This opens with click or keyboard activation. Use a route appropriate to the
  caller; the help URL above is illustrative.

  ## A LiveView action and a dismiss button

      <Tooltip.render id="report-help" label="Report actions" mode={:popover}>
        <:trigger>Report options</:trigger>
        <:content>
          Export the current view for further analysis.
          <button type="button" phx-click="export_report">Export report</button>
          <button type="button" data-dismiss-tooltip>Close</button>
        </:content>
      </Tooltip.render>

  The caller must handle `export_report`. Export keeps the popover open; Close
  dismisses it and returns focus to the trigger.

  ## Custom styles and preferred placement

      <Tooltip.render
        id="custom-metric-help"
        trigger_id="custom-metric-help-button"
        label="Metric definition"
        position="bottom"
        align="right"
        offset={8}
        class="w-64 rounded-sm border border-Border-border-default bg-Surface-surface-background px-3 py-2 text-xs font-bold leading-4 text-Text-text-high shadow"
        trigger_class="inline-flex h-5 w-5 items-center justify-center rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
      >
        <:trigger><Icons.info /></:trigger>
        <:content>A definition styled by the caller.</:content>
      </Tooltip.render>
  """
  def render(assigns) do
    assigns =
      assigns
      |> assign(:trigger_id, assigns.trigger_id || "#{assigns.id}-trigger")
      |> assign(:bubble_class, assigns.class || default_classes())

    ~H"""
    <div
      id={@id}
      phx-hook="Popover"
      data-tooltip-mode={@mode}
      data-tooltip-position={@position}
      data-tooltip-align={@align}
      data-tooltip-offset={@offset}
      class="inline-flex items-center"
    >
      <button
        id={@trigger_id}
        type="button"
        data-tooltip-trigger
        aria-label={@label}
        aria-describedby={@mode == :tooltip && "#{@id}-content"}
        aria-controls={@mode == :popover && "#{@id}-content"}
        aria-expanded={@mode == :popover && "false"}
        aria-haspopup={@mode == :popover && "dialog"}
        popovertarget={@mode == :popover && "#{@id}-content"}
        class={@trigger_class}
      >
        {render_slot(@trigger)}
      </button>
      <div
        id={"#{@id}-content"}
        data-tooltip-content
        popover={if @mode == :popover, do: "auto", else: "manual"}
        role={if @mode == :popover, do: "dialog", else: "tooltip"}
        aria-label={@mode == :popover && @label}
        hidden
        class={[
          "fixed z-[9999]",
          case @arrow do
            true -> "border-0 bg-transparent p-0 overflow-visible"
            false -> @bubble_class
          end
        ]}
        style="inset: auto; margin: 0;"
      >
        <%= case @arrow do %>
          <% true -> %>
            <div data-tooltip-body class={["block", @bubble_class]}>
              {render_slot(@content)}
            </div>
            <span data-tooltip-arrow aria-hidden="true" class="pointer-events-none absolute h-2 w-3">
              <svg
                width="12"
                height="8"
                viewBox="0 0 12 8"
                fill="none"
                focusable="false"
                class="block"
              >
                <path data-tooltip-arrow-fill d="M0 8L6 0L12 8Z" />
                <path data-tooltip-arrow-border d="M0 8L6 0L12 8" fill="none" />
              </svg>
            </span>
          <% false -> %>
            {render_slot(@content)}
        <% end %>
      </div>
    </div>
    """
  end

  defp default_classes do
    "px-3 py-2 min-w-[210px] max-w-[260px] text-Text-text-high text-sm font-normal leading-5 " <>
      "bg-Surface-surface-background border-[0.5px] border-Border-border-default " <>
      "rounded-sm shadow text-left"
  end
end

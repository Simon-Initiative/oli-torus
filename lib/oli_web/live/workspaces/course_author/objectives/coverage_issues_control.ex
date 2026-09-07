defmodule OliWeb.Workspaces.CourseAuthor.Objectives.CoverageIssuesControl do
  @moduledoc """
  Toolbar toggle for the Coverage Issues filter: an icon + label button with
  an affected-objective count badge, styled per the governed Figma brief
  (`docs/exec-plans/current/epics/objectives-editor/coverage_filter/phase-1-figma-brief.md`
  §2/§2b).

  Presentation only — this component does not know about the `filter`/URL
  state contract. The caller passes `count` (from
  `Oli.Authoring.ObjectiveCoverage.Issues.flagged_top_level_ids/2`) and
  `active`, and wires `click` to a `JS.push("apply_filter", ...)` that
  toggles the `"coverage_issues"` key in the existing `filter` map.

  Deliberately hand-rolled rather than composing
  `OliWeb.Components.DesignTokens.Primitives.Button`: its `:pill` variant
  reports `aria-expanded` (disclosure/dropdown semantics), not the
  `aria-pressed` toggle semantics a persistent filter needs, and its
  `:danger` variant is a transparent-background/bordered treatment that
  does not match this control's filled background states.

  The active-state badge matches the Figma-verified light-mode look exactly
  (`Icon-icon-danger` red fill, white text) but overrides dark mode
  explicitly to `Fill-fill-danger`'s dark value (`#33181A`) with
  `Text-text-high`'s dark value (`#EEEBF5`): using `Icon-icon-danger`'s own
  dark value (a light coral, `#FF8787`) with white text is only ~2.3:1
  contrast, because the active badge state was never verified against a
  dark-mode Figma node — no such node was supplied. The dark-mode override
  is therefore an assumption, not a verified Figma value; it reuses a pairing
  already proven safe in both themes elsewhere in this design system (the
  warning banner) and passes WCAG AA (13.9:1). Same explicit-hex-per-theme
  pattern already used by `Icons.settings/1` (`stroke-[#757682]
  dark:stroke-[#BAB8BF]`).

  Rendered from `ObjectivesLive.render/1`'s toolbar.
  """
  use Phoenix.Component

  alias OliWeb.Icons

  attr :count, :integer, required: true
  attr :active, :boolean, default: false
  attr :click, :any, default: nil
  attr :id, :string, default: nil

  def coverage_issues_control(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@click}
      aria-pressed={to_string(@active)}
      class={[
        "inline-flex h-[38px] shrink-0 items-center gap-2 rounded-md border border-Border-border-default px-3 text-sm font-semibold text-Text-text-high transition hover:bg-Surface-surface-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        if(@active, do: "bg-Fill-fill-danger", else: "bg-Background-bg-primary")
      ]}
    >
      <span aria-hidden="true">
        <Icons.warning_triangle class="h-[13px] w-[14px] stroke-Text-text-danger" />
      </span>
      <span class="whitespace-nowrap">Coverage Issues</span>
      <span class={[
        "inline-flex min-w-[19px] items-center justify-center rounded-full px-[6px] py-[2px] text-[11px] font-bold leading-[11px]",
        if(@active,
          do: "bg-[#CE2C31] text-white dark:bg-[#33181A] dark:text-[#EEEBF5]",
          else: "bg-Fill-fill-danger text-Table-text-danger"
        )
      ]}>
        {@count}
      </span>
    </button>
    """
  end
end

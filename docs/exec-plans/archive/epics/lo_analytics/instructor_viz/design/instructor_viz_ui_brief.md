# UI Implementation Brief — Instructor Expanded LO Visualization (MER-5814)

## Design Sources

- Primary source: Figma file `Learning Objectives Updates` (`iVKgFJwC1iKP7jmJBGILOK`)
- Supporting sources: `docs/exec-plans/current/epics/lo_analytics/instructor_viz/informal.md`
- Jira references: MER-5814
- Figma node ids / links:
  - `346:6145` — "Expanded" — full-page context, default (no group selected) state, embedded inside the Learning Objectives table row
  - `358:11956` — "Default" — cropped default state (no group selected, table hidden)
  - `349:11077` — "Needs Support" — group selected, table open beside chart
  - `349:11526` — "Excelling" — group selected, table open beside chart
  - `349:11974` — "Limited Activity" — group selected, table open beside chart

All 5 links the ticket provides were inspected directly (metadata + variable defs), not just the primary linked node. No additional un-linked sibling frames with materially different states were found near these nodes on inspection — the only unlinked artifacts nearby are two hi-fi reference screenshots (`346:6499`, a pasted screenshot) that are decorative annotations, not separate design states. Two states are **not** covered by any linked node and should be confirmed before implementation (see Open Questions): the **empty-group state** (ticket §"Empty State") and **keyboard-focus visuals** (ticket §"Accessibility Guidelines").

## Implementation Surface

- Surface: `mixed` — Elixir/LiveView owns the expanded-row lifecycle and student table; React/SVG (mounted via LiveReact) owns the interactive matrix chart, consistent with the existing `DotDistributionChart` pattern.
- Target user flow: Instructor Dashboard → Insights → Learning Objectives tab → expand a Learning Objective row.
- Responsive considerations: Not covered by the linked Figma nodes — all 5 frames are the ~1512px desktop breakpoint. No mobile/tablet variant is linked. Flag as open question; the existing `DotDistributionChart` already has some resize/visibility handling for expandable rows that should be reused as a baseline.
- Interaction/state considerations:
  - Default: no group selected, no highlight, table hidden.
  - Group selected: matrix region highlighted, table appears beside the chart (not below), only one group selected at a time.
  - Switching groups: previous group deselects, new group highlights, table content updates without requiring close first.
  - Closing (via header "X" or re-clicking the selected group): table closes, selection clears, chart returns to default.
  - Keyboard: groups must be selectable via keyboard, table controls (checkboxes, Email, Load More, Close) must be focusable, with visible focus indicators — none of this is depicted in any static Figma frame and must be designed/confirmed during implementation, not inferred from the mock.

## Design System Alignment

- Shared vs local decision: **keep feature-local**, with one exception already resolved — reuse the existing shared `OliWeb.Delivery.LearningObjectives.Proficiency.chip/1` component as-is for the Proficiency column value.
- Rationale: `lib/oli_web/components/design_tokens/` currently contains only a `Button` primitive (`primitives/button.ex`); `assets/src/components/design_tokens/` does not exist yet. The design-token extraction effort in this codebase is nascent, and this ticket's new pieces (2D matrix chart, group-based table) are not generic cross-feature primitives — they are specific to this analytics surface, matching how `informal.md`'s technical approach already frames this as a rework of `ExpandedObjectiveView`/`DotDistributionChart`/`StudentProficiencyList`, not a new design-system primitive.
- Existing design-system references consulted:
  - `lib/oli_web/components/delivery/learning_objectives/proficiency.ex` (chip/color tokens — confirmed to already match the Figma variable defs pulled from node `349:11077`, see Token Mapping)
  - `lib/oli_web/components/design_tokens/primitives/button.ex`
  - `lib/oli_web/live/dev/design_tokens_live.ex` (the `/dev/design_tokens` catalog referenced by repo convention, currently sparse)

## Token Mapping

Pulled via `get_variable_defs` on node `349:11077` (Needs Support, selected state) and cross-checked against `proficiency.ex`:

- Background / surface: `Background/bg-secondary` (#ffffff), `Table/table-top-row`, `Table/table-row 1` (#f3f4f8), `Table/table-row 2` (#e3e7eb), `Table/table-hover` (#f2f9ff)
- Text: `Text/text-high` (#353740), `Text/text-low-alpha` (#757682), `Text/text-charcoal`, `Text/text-white`
- Border / divider: `Border/border-default` (#ced1d9), `Border/border-subtle` (#e6e9f2), `Border/border-bold` (#8ab8e5), `Table/table-border`
- Fill / accent (proficiency semantics — **already implemented** in `Proficiency.chip_colors/1`, reuse directly):
  - Low → `Icon/icon-danger` #ce2c31 / `Fill/fill-danger` #feebed / `Border/border-danger` #ff4040
  - Medium → `Icon/icon-accent-orange` #bf5b13 / `Specialty Tokens/Icon/icon-tile-tag-orange` #ffb387
  - High → `Text/text-accent-green` #218358
- Icon: `Icon/icon-default` (#757682), `Icon/icon-white`
- Spacing / layout: `spacing-050` (4), `spacing-075` (6), `spacing-100` (8), `spacing-150` (12), `spacing-200` (16), `spacing-300` (24), `radius-075` (6), `radius-round` (999)
- Typography: `Body/M.500`/`M.600`/`M.700` (16px Open Sans), `Label/S.600` (14px), `Label/M.700` (16px bold), `Label/XS.700 (Caps)` (12px bold caps)
- Token gaps requiring approval: none of the extracted tokens are new — every color/spacing/type token above already exists in the design system and most already have Elixir-side equivalents wired up (`Fill-Chip-Gray`, `Text-text-danger`, etc. in `proficiency.ex`). No new token needs to be created for this ticket.

## Icon Mapping

- Existing icons to reuse:
  - `Icons.warning_16` (already used by `Proficiency.chip/1` for the "Low" indicator) — reuse for any low-proficiency flagging in the new table.
  - Chevron icons (`16px/Chevron-Down`, `16px/Chevron-Right`) — already used throughout the codebase for sortable table headers and buttons; no new asset needed.
  - `mail-up` icon on the Email button — matches the existing `EmailButton` component's icon (`lib/oli_web/components/delivery/students/email_button.ex`); confirm it renders the same icon before assuming reuse.
  - `20px/Close` for the table header "X" — check `OliWeb.Icons` for an existing close icon before adding one.
- Icons that need extension: the per-group header badge (Figma instance `Badge/Unread-Messages`) is reused with the **same instance name across all three groups** (Needs Support, Excelling, Limited Activity) in the metadata pass — it is not visually confirmed per-group whether the icon itself changes (e.g., support icon vs. trophy vs. clock) or only the surrounding badge color changes. This needs a screenshot-level visual check before implementation; flagged in Open Questions.
- Notes on surface-specific icon implementation: icons inside the React/SVG chart overlay (dots, group highlight) are drawn as SVG shapes in Figma (`ellipse` nodes), not icon components — implement as plain SVG circles in the React overlay, consistent with `DotDistributionChart`'s existing dot-rendering approach.

## Component Reuse Plan

- Existing components/patterns to reuse:
  - `OliWeb.Delivery.LearningObjectives.Proficiency.chip/1` — Proficiency column value, unchanged.
  - `OliWeb.Components.Delivery.Students.EmailButton` — Email button and modal-payload forwarding, per `informal.md`'s technical approach.
  - `OliWeb.Common.React.component/4` / `PhoenixLiveReact.live_react_component` — mounting pattern for the new chart component.
  - Existing table-cell / sortable-header conventions from `StudentProficiencyTableModel` and `ObjectivesTableModel`.
- Components to extend/replace:
  - `assets/src/components/misc/DotDistributionChart.tsx` → superseded by a new component (e.g. `StudentDistributionMatrix.tsx`), per `informal.md`'s recommendation (2D/group-based chart is different enough from the 1D proficiency bar to warrant a new component rather than retrofitting).
  - `OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList` / `StudentProficiencyTableModel` → adapted into a group-based table (filters by `distribution_group`, not `proficiency_range`; new header block with count/explanation/action; adds Activity Completion column; adds Load More; adds the extra proficiency sub-filter for `Needs Support` / `Excelling` / `Limited Activity` confirmed present in all three Figma states via the `Drop-down filter` component next to the Email button).
- Proposed extractions: none recommended at this time — see Design System Alignment rationale.
- States that must be supported (per Figma + ticket, cross-referenced):
  - Default (no selection, table hidden) — confirmed in `346:6145` / `358:11956`.
  - Group selected + table open, per group (Needs Support / Excelling / Limited Activity) — confirmed in `349:11077` / `349:11526` / `349:11974`, including per-group guidance copy (extracted verbatim below).
  - Switching between groups — implied by table structure being identical across the three linked states; not shown as a transition/animation.
  - Closing via header "X" or re-clicking selected group — matches ticket text; "X" icon confirmed present in header (`20px/Close`), re-click-to-close behavior not visually depicted (interaction-only, not a distinct visual state).
  - Empty state (group with 0 students) — **not present in any linked Figma frame**. Open question.
  - Keyboard focus / keyboard-selectable groups — **not present in any linked Figma frame**. Open question.

Per-group guidance copy extracted verbatim from Figma (for FDD/implementation reference, avoids re-deriving from the ticket's paraphrase):

- **Needs Support**: "Students are actively completing the linked learning activities, but are still unlikely to apply this learning objective. Review common misconceptions, additional practice materials, or reach out to students to offer support."
- **Excelling**: "Students are actively completing the linked learning activities and are likely to apply this objective across linked activities."
- **Limited Activity**: "Students in this group have completed fewer activities related to this learning objective. Some may not yet have enough evidence for a proficiency estimate, while others may have demonstrated proficiency based on limited activity."

Chart layout confirmed from Figma geometry (relevant to FDD group-assignment rules, ties to `informal.md`'s "Open group-rule decisions"):

- Chart is a 2x2 region split at the 50% activity-completion line (y) and 50% proficiency line (x).
- Top-left (low proficiency, high activity) = **Needs Support**.
- Top-right (high proficiency, high activity) = **Excelling**.
- The entire bottom half (both proficiency sides, low activity) is rendered as **one merged "Limited Activity" region spanning the full chart width** — visually confirming the ticket's rule that Limited Activity is activity-only and ignores proficiency. This is a layout detail the FDD should call out explicitly: the matrix is drawn as 3 regions, not a strict 4-quadrant grid.
- Sample data shown: Needs Support = 4, Excelling = 5, Limited Activity = 12 (dots rendered as individual circles per student, not grouped/stacked in these mocks — differs from the current `DotDistributionChart`'s "6+ students become one larger dot" behavior; confirm whether that grouping rule still applies to the new matrix or whether it always renders one dot per student).

## File Targets

- Primary implementation files:
  - `lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`
  - `lib/oli_web/components/delivery/learning_objectives/student_proficiency_list.ex` and `student_proficiency_table_model.ex` (or their replacements)
  - `assets/src/components/misc/DotDistributionChart.tsx` (or new `StudentDistributionMatrix.tsx`)
  - `assets/src/apps/Components.tsx` (LiveReact registration)
- Shared component targets: `lib/oli_web/components/delivery/learning_objectives/proficiency.ex` (reuse only, no changes expected)
- Feature-local component targets: new group-assignment helper module (per `informal.md`'s "Define Group Assignment In One Place" recommendation)
- Styling/token touch points: none — all required tokens already exist (see Token Mapping)

## Open Questions / Requires Approval

- Unmapped colors or tokens: none blocking — but the exact color assigned to each group's badge/highlight (Needs Support vs. Excelling vs. Limited Activity) was not visually confirmed from metadata alone; a screenshot pass or design confirmation is recommended before final CSS.
- Missing design states:
  - No linked Figma frame shows the **empty-group state** described in the ticket ("no students currently belong to that category").
  - No linked Figma frame shows **keyboard focus indicators** required by the Accessibility Guidelines.
  - No linked Figma frame shows a **responsive/narrow-viewport** layout.
  - No linked Figma frame shows the **group-switching transition** or the **re-click-to-deselect** interaction explicitly (behavior is described in the ticket text only).
- Ambiguous interactions: whether individual dots continue to merge into one larger dot at 6+ same-value students (current `DotDistributionChart` behavior) or whether the new matrix always renders one dot per student (Figma mocks show one dot per student at low counts, inconclusive at scale).
- Reuse/extraction decisions needing confirmation: none — feature-local placement is a low-risk default given the current design_tokens/ footprint is minimal.
- Anything else that should be confirmed before coding:
  - The per-group header badge icon (`Badge/Unread-Messages` instance, reused identically across all 3 group metadata dumps) — confirm whether the icon differs by group or only its color/background does.
  - Whether the "Drop-down filter" next to the Email button in each group's table header is the same "Proficiency filter" the ticket describes for sorting (low-first / medium-first / not-enough-info-first per group), since Figma only shows the closed dropdown control, not its open/expanded option list.
  - This brief inherits the same open questions already logged in `informal.md` regarding the precise definition of "Activity Completion" and the exact "high activity" threshold — those are business-rule questions, not design-fidelity questions, and should be resolved in the PRD, not here.

# UI Implementation Brief

## Design Sources

- Primary source:
  - `MER-5254` Figma component: `Instructor Intelligent Dashboard`, `Assessments Tile`
- Supporting sources:
  - Jira attachment examples for the completion-status chip states (`"Bad status"` / `"Good status"`)
  - Existing `Student Support` tile implementation for dashboard-specific spacing, card chrome, and action layout conventions
  - Torus design-system Figma references for layout, spacing, colors, typography, icons, and buttons
- Jira references:
  - `https://eliterate.atlassian.net/browse/MER-5254`
- Figma node ids / links:
  - `https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=895-8349&t=EfwdptDGcPWmCVAN-1`

## Implementation Surface

- Surface: `liveview/heex`
- Target user flow:
  - Instructor opens Intelligent Dashboard
  - Instructor sees the `Assessments` tile in the `Content` section
  - Instructor scans assessment list, expands one row, reviews completion chip, distribution bars, metrics, and action affordances
  - Instructor navigates to deeper assessment workflows from tile actions
- Responsive considerations:
  - Default desktop layout can keep the expanded detail view in two columns
  - Below `xl`, the expanded detail regions should stack vertically instead of forcing chart/metrics compression
  - Row header metadata should wrap under the title before allowing horizontal overflow
- Interaction/state considerations:
  - Collapsed and expanded row states are first-pass fidelity targets
  - Completion chip color is semantically meaningful and should stay tied to status, not arbitrary styling
  - Empty, loading, unavailable, hover, focus, and action-disabled states need explicit handling

## Design System Alignment

- Shared vs local decision:
  - `keep feature-local`
- Rationale:
  - The tile layout, histogram composition, and disclosure structure are feature-specific dashboard composition, not a new cross-feature primitive
  - Shared primitives should still be reused where already available, especially buttons and icons
- Existing design-system references consulted:
  - Layout
  - Spacing
  - Colors
  - Typography
  - Icons
  - Buttons

## Token Mapping

- Background / surface:
  - outer tile shell: `bg-Surface-surface-primary`
  - collapsed row surface: `bg-Surface-surface-secondary`
  - expanded inner panels: `bg-Background-bg-primary`
- Text:
  - primary headings and values: `text-Text-text-high`
  - supporting copy and metadata: `text-Text-text-low`
  - secondary/deemphasized labels: `text-Text-text-low-alpha`
  - link/button text: prefer `text-Text-text-button`
- Border / divider:
  - tile, row, and panel borders: `border-Border-border-subtle`
  - interactive button borders: `border-Border-border-default`
- Fill / accent:
  - good completion chip: `bg-Fill-Chip-Success`
  - bad completion chip: `bg-Fill-Chip-Error`
  - neutral chip fallback: `bg-Fill-Chip-Gray`
  - histogram bars: keep feature-local use of existing chart fill token such as `bg-Fill-Chart-fill-chart-blue-active` unless product/design specifies a per-metric color split
- Icon:
  - tile icon: `OliWeb.Icons.assignments`
  - disclosure affordance: `OliWeb.Icons.chevron_down`
  - future action icons should come from `OliWeb.Icons` and reuse existing dashboard conventions before proposing new icons
- Spacing / layout:
  - card and panel spacing should stay on existing Tailwind scale values (`p-3`, `p-4`, `gap-2`, `gap-3`, `gap-4`) unless a fidelity miss requires bounded arbitrary values
  - row header content should prefer wrap/flex fallbacks over narrower fixed-width columns
- Typography:
  - tile title: `text-lg font-semibold leading-6`
  - row title: `text-base font-semibold leading-6`
  - supporting copy: `text-sm leading-5` or `leading-6`
  - micro labels / chart captions: `text-xs` or `text-[11px]`
- Token gaps requiring approval:
  - The ticket references mean-score color semantics aligned with the gradebook, but the exact token mapping for that threshold state is not yet pinned here
  - The design source does not fully specify a dedicated unavailable/error surface beyond generic dashboard feedback patterns

## Icon Mapping

- Existing icons to reuse:
  - `OliWeb.Icons.assignments`
  - `OliWeb.Icons.chevron_down`
  - future action buttons can likely reuse existing email / navigation / send icons already present in `OliWeb.Icons`
- Icons that need extension:
  - none identified for the current tile shell and disclosure state
- Notes on surface-specific icon implementation:
  - Because this tile is HEEx/LiveView, use `OliWeb.Icons`, not React-side icon components

## Component Reuse Plan

- Existing components/patterns to reuse:
  - dashboard tile chrome and spacing conventions already used by `StudentSupportTile`
  - `OliWeb.Components.DesignTokens.Primitives.Button` for final action buttons
  - merged `student_support` draft-email modal pattern for the future email action
- Components to extend:
  - `AssessmentsTile` should own its disclosure composition and histogram layout locally
  - if action styling converges with other dashboard tiles, prefer composing `Button.button` rather than introducing local button classes
- Proposed extractions:
  - none for Phase 2
  - if the completion chip shape/state appears in multiple tiles, reevaluate extraction later as a dashboard/shared feedback primitive
- States that must be supported:
  - loading
  - unavailable/error
  - no-assessment hidden/empty behavior as determined by section composition
  - collapsed row
  - expanded row
  - disclosure hover/focus-visible
  - disabled action button state until each action is wired

## File Targets

- Primary implementation files:
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex`
- Shared component targets:
  - reuse `lib/oli_web/components/design_tokens/primitives/button.ex`
  - reuse the merged dashboard email-modal path when Phase 3 wires email behavior
- Feature-local component targets:
  - keep histogram, metrics panel, disclosure header, and tile layout within the assessments tile module unless later reuse emerges
- Styling/token touch points:
  - existing tokenized Tailwind utility classes in the tile module
  - avoid adding new design tokens unless product/design confirms a real gap

## Open Questions / Requires Approval

- Unmapped colors or tokens:
  - Mean-score threshold colors need confirmation against the existing assessment scores gradebook logic
- Missing design states:
  - The design source does not fully specify loading, unavailable/error, empty-with-no-submissions, hover, focus-visible, or responsive stack behavior
- Ambiguous interactions:
  - The design implies disclosure per row, but does not explicitly settle whether multiple rows may stay open simultaneously
  - The exact visual treatment for `"Review questions"` and `"Email students not completed"` in the expanded panel still needs to be reconciled with the merged `student_support` action pattern
- Reuse/extraction decisions needing confirmation:
  - If `assessment_tile` becomes the second consumer of the same dashboard draft-email modal flow, extraction to a neutral shared dashboard modal should be revisited
- Anything else that should be confirmed before coding:
  - Whether the score-distribution bars should stay a simple token-colored histogram in HEEx/CSS or adopt a richer fidelity target later if product/design expects tighter visual parity with Figma

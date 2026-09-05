# UI Implementation Brief

## Design Sources

- Primary source: Current Experiments group editor, experiment details LiveView, and established Torus authoring patterns. This feature intentionally has no feature-level Figma design.
- Supporting sources: Torus design-system Layout, Spacing, Colors, Typography, Icons, Buttons, and Flash Messages references listed in `.agents/skills/implement_ui/references/design_system_sources.md`.
- Jira references: None supplied; Jira is not modified by this phase.
- Figma node ids / links: Design-system nodes `2:25`, `476:3011`, `5:31`, `2:22`, `2:24`, `1007:140`, and `4478:17891` are optional supporting references only. No feature-level node is required.

## Implementation Surface

- Surface: `liveview/heex` by default. Use LiveComponents for reusable stateful feature controls; introduce React only if repository inspection shows a materially better existing reusable client-side component or an interaction that LiveView cannot support cleanly.
- Target user flow: Strategy-specific Alternatives Group management on the Alternatives and Experiments routes; one experiment-owned group and policy configuration; lifecycle-aware read-only views; bounded posterior reporting after draft.
- Responsive considerations: Use familiar responsive card, grid, stacked-form, and horizontally scrollable table patterns. Tables/cards must remain legible at narrow widths, dense condition metrics need a clear stacking/overflow treatment, and action controls must not obscure lifecycle state.
- Interaction/state considerations: draft edit/validation, loading and empty states, lifecycle confirmations, paused-versus-guardrail distinctions, explicit refresh, expandable alpha/beta details, keyboard-accessible tabs, and monitoring warnings.

## Design System Alignment

- Shared vs local decision: `keep feature-local` for experiment configuration/report compositions; `extend existing design_tokens shared primitive` only when implementation uncovers a genuine missing cross-feature button, badge, tab, or feedback state.
- Rationale: Experiment graphs and posterior summaries are domain-specific. Buttons, badges, tabs, and feedback are cross-feature primitives and should reuse the design-token consumption layer rather than gain local variants.
- Existing design-system references consulted: repo token/theme waypoints, canonical design-system references, and the existing authoring/Experiments surfaces. The implementation should favor consistency with the running product over introducing a novel visual language.

## Token Mapping

- Background / surface: existing semantic page and card surface utilities; do not add Bootstrap/Sass styling to new UI.
- Text: existing default, muted, danger, success, and warning semantic text tokens.
- Border / divider: existing neutral and semantic border utilities.
- Fill / accent: existing primary, success, warning, danger, and neutral semantic fills.
- Icon: `OliWeb.Icons` on the LiveView/HEEx surface.
- Spacing / layout: native Tailwind spacing/grid utilities; avoid copied arbitrary Figma values.
- Typography: existing heading, body, label, numeric/tabular conventions.
- Token gaps requiring approval: none anticipated. If implementation reveals a semantic role that cannot use an existing token, prefer the nearest established system pattern and document any proposed shared-token addition separately.

## Icon Mapping

- Existing icons to reuse: existing disclosure/chevron, warning, refresh, add, edit, delete, and lifecycle action icons where present in `OliWeb.Icons`.
- Icons that need extension: none anticipated; keep the UI minimal and text-led when no established icon improves comprehension.
- Notes on surface-specific icon implementation: verify every requested icon first against `OliWeb.Icons` and design-system node `2:24`; do not add one-off inline SVGs.

## Component Reuse Plan

- Existing components/patterns to reuse: the current Experiments group editor as the interaction baseline, shared modal/confirmation behavior, existing status badges, form feedback, paged section table, and accessible disclosure patterns.
- Components to extend: extract a shared Alternatives Group management component parameterized by strategy, labels, permissions, and creation behavior; keep experiment graph configuration and posterior report feature-local.
- Proposed extractions: only demonstrated cross-feature primitive gaps should move to `lib/oli_web/components/design_tokens/` and be cataloged under `/dev/design_tokens`; link a canonical design-system source when one exists.
- States that must be supported: empty, loading/refreshing, validation error, draft editable, active/paused read-only structure, completed/archived frozen report, weighted-random metric omission, warm-up/fixed-control/traffic-cap modes, assignment imbalance warning, and lifecycle pause distinct from guardrail configuration.

## File Targets

- Primary implementation files: `lib/oli_web/live/workspaces/course_author/experiments_live.ex`, `lib/oli_web/live/workspaces/course_author/experiment_details_live.ex`, and `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`.
- Shared component targets: existing Alternatives editor modules first; `lib/oli_web/components/design_tokens/` only for an approved cross-feature primitive gap.
- Feature-local component targets: a shared strategy-filtered group manager near the course-author LiveViews plus experiment-specific configuration/report components.
- Styling/token touch points: Tailwind utilities and existing light/dark semantic tokens. Avoid new Bootstrap classes and dedicated feature stylesheets.

## Open Questions / Requires Approval

- Unmapped colors or tokens: none currently; use existing semantic light/dark tokens.
- Missing design states: resolve responsive treatment, metric density, warning hierarchy, and empty/loading layouts through common Torus patterns during implementation.
- Ambiguous interactions: choose the smallest conventional interaction for group mapping, threshold editing, refresh feedback, and posterior-detail disclosure; avoid custom interaction models unless required by accessibility or complexity.
- Reuse/extraction decisions needing confirmation: decide from concrete reuse found during implementation, defaulting domain-specific compositions to feature-local LiveComponents.
- Anything else that should be confirmed before coding: no feature-level design approval is required. Implement the minimum UI and forms needed to expose the specified functionality, support light and dark mode, then run the application and iteratively test and refine usability, responsive behavior, accessibility, and visual consistency before completing the UI phase.

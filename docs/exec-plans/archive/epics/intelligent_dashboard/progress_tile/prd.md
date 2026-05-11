# Progress Tile - Product Requirements Document

## 1. Overview
Deliver the Intelligent Dashboard Progress tile for `MER-5251` so instructors can quickly understand completion progress for the currently selected course scope and identify content that is behind schedule. This work item covers the scoped tile UI, its non-UI projection contract, the schedule-aware bar chart behavior, and the accessibility and interaction details required to make the tile implementation-ready.

The visual source of truth is the Figma work attached to `MER-5251`, using the user-provided selected node `1074:28220` in `Instructor-Intelligent-Dashboard` as the current implementation reference, plus the tile-specific Jira-linked variants for no-schedule, small-course, modules, and pages states.

Designer confirmation from Jess Fortunato clarified one important edge case for this feature: the x-axis should show the direct children of the filtered scope even when those children are structurally mixed (for example modules and standalone pages at the same level). In those mixed cases, the x-axis label should use the generic copy `Course Content`.

Jess Fortunato also clarified the intended meaning of the schedule marker. The marker is not meant to be a precise schedule-management indicator; it is a general "where are we in the course?" cue. Its meaning varies by scope: at course scope it should indicate the current scheduled unit, at unit scope it should indicate the current scheduled direct child of that unit, and at module scope it should indicate the next scheduled page whose scheduled date is closest to today.

## 2. Background & Problem Statement
Instructors need an at-a-glance way to judge whether learners are progressing through course content, but the current dashboard work does not yet provide a concrete, hierarchy-aware progress visualization. The missing piece is not only the data projection; the ticket also depends on a chart-heavy visual design with explicit behaviors for thresholding, schedule overlays, pagination, label truncation, and y-axis mode changes.

Without a precise product and UI contract, implementation risk is high in three places:

- the tile can drift from the approved Figma behavior for schedule-aware and paginated chart states
- projection logic can leak into the LiveView or browser layer instead of staying in non-UI code
- accessibility and rapid-update behavior can be under-specified, leading to regressions once the dashboard scope and tile-local controls interact

## 3. Goals & Non-Goals
### Goals
- Deliver a Progress tile in the Intelligent Dashboard engagement section for instructor-facing section views.
- Keep progress aggregation and scope-to-axis derivation in non-UI projection code backed by dashboard oracle data.
- Match the approved Figma tile behavior for chart layout, schedule overlays, threshold control, count/percentage toggle, pagination, and empty states.
- Define the implementation surface, token mapping, icon guidance, and file targets clearly enough that UI implementation can proceed without a separate design brief artifact.
- Preserve keyboard, screen-reader, and 200% zoom usability for the tile and its controls.

### Non-Goals
- Building or redesigning the destination `Insights > Content` page reached from `View Progress Details`.
- Introducing new global dashboard layout primitives beyond what is already owned by the Intelligent Dashboard shell and engagement section chrome.
- Redefining oracle ownership, cache policy, or cross-tile data orchestration already specified by the dashboard epic and oracle work items.
- Creating or changing design tokens as part of this work item unless a later implementation finds a proven token gap that needs approval.

## 4. Users & Use Cases
- Instructor: opens the Learning Dashboard and immediately sees progress counts for the current course scope.
- Instructor: adjusts the completion threshold to match a practical definition of "complete" and sees the chart update without leaving the page.
- Instructor: switches between student count and class percentage to understand the same data in different terms.
- Instructor: uses the schedule-aware chart to identify content that is behind the current scheduled point.
- Instructor: navigates to `Insights > Content` from the tile when the high-level chart suggests deeper investigation is needed.
- Instructor: interprets the dotted schedule marker as a general position in the curriculum rather than an exact scheduler detail, with the marker resolving to units, direct-child modules/pages, or pages depending on the current scope.

## 5. UX / UI Requirements
- Design Sources:
  - Primary source: selected Figma node `1074:28220` from `https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=1074-28220&m=dev`
  - Supporting sources: Jira-linked nodes `895:8344`, `1074:43497`, `1074:26453`, `1059:16420`, and `1059:17206` embedded in `MER-5251`
  - Jira source of truth: `https://eliterate.atlassian.net/browse/MER-5251`
- Implementation Surface:
  - Surface: `mixed`
  - The tile chrome and interaction ownership belong in Phoenix LiveView/HEEx under the Intelligent Dashboard engagement section.
  - The bar chart runtime should use the established browser-managed Vega/Vega-Lite pattern already used by the dashboard prototype hooks, with LiveView remaining the source of authoritative tile state.
- Design System Alignment:
  - Shared vs local decision: `keep feature-local`
  - The Progress tile is a dashboard-specific composite and should stay feature-local in `intelligent_dashboard/tiles/`, while continuing to consume existing shared section chrome, token classes, dropdown/button patterns, and icon modules.
  - Reuse shared tokens and shared icon modules before introducing any new primitive.
- Token Mapping:
  - Section shell background: `Background-bg-secondary`
  - Tile surface: `Surface-surface-primary`
  - Tile border: `Border-border-subtle`
  - Tile shadow: existing card shadow token/value aligned to `Shadow/shadow-card`
  - Title text: `Text-text-high`
  - CTA text: `Text-text-button`
  - Secondary body text: `Text-text-high` or `Text-text-low` depending on semantic prominence
  - Chart danger overlay behind the scheduled point: `Fill-fill-danger`
  - Bars and scrollbar accents should use existing accent/chart tokens already present in the Figma variables and repo theme before any hardcoded values are considered
  - Spacing/radius values should follow the selected Figma node mappings: `spacing-050`, `spacing-075`, `spacing-100`, `spacing-150`, `spacing-200`, `spacing-300`, `spacing-400`, and `radius-025`, `radius-075`, `radius-100`, `radius-150`
- Icon Mapping:
  - Prefer `OliWeb.Icons` for section controls and pagination chevrons because the owning surface is LiveView/HEEx.
  - Reuse the existing `info` and chevron icons where the visual match is acceptable.
  - If the Progress/trending icon used in the tile header does not already exist in `OliWeb.Icons`, extend the canonical icon module instead of introducing a local one-off SVG.
- Component Reuse Plan:
  - Reuse `DashboardSectionChrome` for the outer engagement section container.
  - Keep the Progress tile composition in `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`.
  - Reuse the existing dropdown/button styling patterns for the completion threshold control and pagination buttons.
  - Reuse the established Vega/Vega-Lite browser hook pattern from `assets/src/hooks/student_support_chart.ts` as the baseline for a dedicated progress chart hook.
- File Targets:
  - Primary implementation files:
    - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
    - `lib/oli/instructor_dashboard/prototype/tiles/progress.ex`
    - `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`
  - Likely browser/runtime target:
    - `assets/src/hooks/progress_tile_chart.ts` or a comparably named feature-local hook
  - Shared targets only if needed:
    - `lib/oli_web/icons.ex`
    - `assets/src/components/misc/VegaLiteRenderer.tsx`
- Interaction and state requirements:
  - The selected dashboard scope determines the set of direct child items shown on the x-axis and should update the tile without stale or orphaned UI state.
  - The x-axis must support structurally mixed direct children of a scope; each rendered bar should retain its own resource type metadata even when the axis-level label uses generic copy such as `Course Content`.
  - When schedule data exists, the current scheduled position must be derived at the same semantic level as the current scope:
    - `course` scope resolves to a scheduled unit-level position
    - `unit` scope resolves to a scheduled direct-child position for that unit
    - `module` scope resolves to the next scheduled page whose scheduled date is closest to today
  - The schedule marker is intentionally approximate and should answer "where are we in the course?" rather than reproduce the full scheduling UI with exact fidelity.
  - Completion threshold, y-axis mode, and pagination are tile-local interaction states and must not trigger a broader scope reload when only tile-local state changes.
  - Tooltips for bars, schedule marker, and completion-threshold help text must be reachable by hover and keyboard focus.
  - Truncated x-axis labels must expose the full content name through an accessible mechanism.
  - Pagination changes must be announced through an `aria-live` region.
  - The chart and controls must remain usable at 200% zoom.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: the tile must satisfy WCAG 2.1 AA expectations for keyboard operation, focus visibility, semantic labeling, screen-reader announcements, and zoom resilience for chart content and controls.
- Reliability: rapid changes to scope, threshold, pagination, or y-axis mode must never leave stale chart state onscreen.
- Performance: this work item inherits the Intelligent Dashboard epic expectation that tile-local interactions acknowledge quickly and do not introduce uncontrolled query fan-out; no additional feature-specific performance budget is introduced here beyond the epic-level targets.
- Privacy and security: the tile is instructor-facing only and must expose aggregate section-scoped progress information rather than learner-private detail in the chart itself.
- Internationalization: user-facing labels, descriptions, tooltip text, axis labels, and empty-state messaging must remain localizable, and numeric values must use existing formatting conventions.

## 9. Data, Interfaces & Dependencies
- The tile depends on the dashboard content-title oracle and progress oracle referenced by the Intelligent Dashboard oracle work.
- Progress projection logic must stay in non-UI code and output a chart-ready model consumed by the LiveView/browser layer.
- The projection contract must include:
  - axis label metadata, including a generic fallback such as `Course Content` for mixed direct-child scopes
  - ordered child content labels, IDs, and per-item resource types
  - completion counts and percentages
  - total class size
  - schedule marker metadata when a schedule exists, derived from the current scope level rather than from an always page-level schedule detail
  - pagination metadata for visible slices
  - empty-state metadata for zero-class-size and no-activity cases
- The UI layer may derive presentational state from the projection, but it must not run independent analytics queries or duplicate business rules for scope-to-axis mapping or completion classification.
  - In particular, the UI must not infer a homogeneous child type for the axis when the scope contains mixed direct children; that classification belongs in projection output.
- The tile depends on the existing dashboard shell, engagement section composition, and the `Insights > Content` navigation path already owned elsewhere in the instructor dashboard.

## 10. Repository & Platform Considerations
- The implementation belongs in the instructor dashboard LiveView surface, not a standalone SPA.
- The existing placeholder and ownership boundaries already point to the correct modules:
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
  - `lib/oli/instructor_dashboard/prototype/tiles/progress.ex`
  - `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`
- The current `student_support_chart.ts` hook demonstrates the preferred browser-hook pattern for Vega/Vega-Lite chart mounting, update suppression, and cleanup; the Progress tile should follow the same shape rather than embedding chart business logic in the hook.
- Because the selected Figma node is the Engagement section container, implementation should treat the Progress tile inside that section as the relevant visual slice and preserve its alignment with the adjacent Student Support tile without broadening this work item into section-level chrome changes.
- Prefer tokenized Tailwind classes already in the repo over arbitrary values when a close match exists; only preserve raw Figma values when the token system cannot express the intended visual behavior.
- UI verification should include LiveView rendering tests plus hook-level/browser behavior checks appropriate for the mixed LiveView + Vega-Lite surface.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track tile render success/failure so dashboard health can be monitored in production-like environments.
- Track meaningful tile-local interactions:
  - `progress_tile.threshold_changed`
  - `progress_tile.mode_toggled`
  - `progress_tile.pagination_changed`
  - `progress_tile.view_details_clicked`
- Monitor empty-state frequency for no-activity and zero-class-size renders to detect unexpected data regressions.
- Success signal: instructors can use the tile to understand scoped progress and navigate to detail views without confusion about scope, schedule state, or chart meaning.

## 13. Risks & Mitigations
- Risk: the schedule overlay and behind-schedule emphasis drift from the approved design.
  - Mitigation: use the Jira-linked Figma variants as explicit supporting references and keep the schedule/no-schedule states called out in requirements and tests.
- Risk: tile-local interaction state triggers broad dashboard reload behavior or stale chart renders.
  - Mitigation: keep tile-local state isolated in the tile component/browser hook and preserve projection ownership in non-UI modules.
- Risk: chart accessibility is treated as optional because Vega-Lite handles rendering.
  - Mitigation: require explicit accessible labels, tooltips, focus behavior, and live announcements around the chart rather than assuming renderer defaults are sufficient.
- Risk: implementation introduces local icons or hardcoded colors that bypass the design system.
  - Mitigation: reuse `OliWeb.Icons` and existing token classes first, and treat any unmapped visual need as an approval-worthy gap.

## 14. Open Questions & Assumptions
### Open Questions
- Which exact upstream oracle or snapshot field should supply the schedule-position payload (`has_schedule?`, `current_resource_id`, `label`, `tooltip`) now that the scope-specific semantics are defined?

### Assumptions
- The selected Figma node `1074:28220` is the current approved implementation context for the Engagement section, and the Progress tile inside it is visually authoritative when combined with the Jira-linked tile variants.
- The `View Progress Details` action should route to the existing `Insights > Content` experience without this work item redefining the destination.
- A dedicated progress chart hook can be added under `assets/src/hooks/` if needed without violating the current dashboard architecture.
- Existing token and icon systems are sufficient for this feature unless implementation uncovers a concrete mismatch that requires approval.
- Progress tile state that materially affects instructor navigation context should be URL-backed using the dashboard tile namespacing rules from `docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`, while remaining tile-local in ownership and avoiding unnecessary scope-wide reloads.

## 15. QA Plan
- Automated validation:
  - add unit tests for projection logic covering direct-child resolution for homogeneous and mixed scopes, threshold changes, percentage/count derivation, schedule metadata, pagination slices, axis-label fallback copy, and empty-state outputs
  - add LiveView or component tests covering rendered controls, CTA presence, schedule/no-schedule messaging, empty states, and stale-update suppression
  - add browser-hook or integration coverage for Vega/Vega-Lite mounting, rerender cleanup, and tile-local interaction synchronization
- Manual validation:
  - compare the implemented tile against the selected Figma node and Jira-linked variants for schedule-aware, no-schedule, modules, pages, paginated states, and mixed-child scopes using the approved `Course Content` axis label
  - verify keyboard navigation, tooltip focus behavior, screen-reader labeling, and `aria-live` announcements for pagination and toggle changes
  - verify the tile at 200% zoom and with long x-axis labels

## 16. Definition of Done
- [ ] `prd.md` follows the required harness PRD section structure and keeps FR/AC canonical in `requirements.yml`
- [ ] `requirements.yml` captures the Progress tile requirements and validates structurally
- [ ] Progress tile product, UI, accessibility, and implementation-surface decisions are explicit enough to code without a separate design brief file
- [ ] Required harness validation commands complete successfully

# Student Support Tile - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/support_tile/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/support_tile/fdd.md`

## Scope
Deliver `MER-5252` in reviewable increments that validate the tile architecture early, keep business rules in non-UI projection layers, and defer visual polish until the data/state/URL contract is proven. The plan intentionally separates:

- non-UI support projection and upstream wiring
- LiveView tile state plus URL-backed interaction state
- chart renderer viability and Figma-driven UI refinement
- student selection and email handoff

This plan assumes multiple developers may work across adjacent dashboard tiles in parallel, so it follows the shared ownership and URL-param conventions captured in `dashboard_ui_composition.md`.

## Clarifications & Default Assumptions
- `PR 1` is an architecture-validation slice, not a final-design slice. Minimal UI is acceptable if it proves data flow, URL patching, and chart/list synchronization.
- The `PR 1` chart is intentionally minimal and provisional; its purpose is to validate renderer viability and LiveView integration, not final Figma fidelity.
- `Vega-Lite` is treated as the initial renderer candidate, but not as an irreversible architectural dependency.
- Tile-local URL params for this feature will use the namespaced shape:
  - `tile_support[bucket]`
  - `tile_support[filter]`
  - `tile_support[page]`
  - `tile_support[q]`
- Tile-local URL patches must reuse the current snapshot/projection and must not trigger scope-wide oracle reload.
- `struggling` is the preferred default bucket, with fallback to the first non-empty bucket in priority order.
- The support tile should graduate to a `live_component` as soon as real local interaction state is introduced.
- UI fidelity against Figma is intentionally delayed until after architecture viability is proven.

## Phase 1: PR 1 - Data, Projection, URL State, and Minimal Interactive Slice
- Goal: Prove the feature architecture end-to-end with minimal UI by wiring data into the tile, validating non-UI projection boundaries, and confirming that donut selection + URL patching + list synchronization work without scope-wide refetch.
- Tasks:
  - [ ] Replace the current thin student-support projection passthrough with a feature-owned projection path that consumes progress/proficiency and student info payloads and emits bucket summaries, student rows, activity status, and default-bucket resolution.
  - [ ] Introduce or align the upstream support-tile wiring so the required data reaches the projection layer through the existing dashboard snapshot/oracle flow.
  - [ ] Convert `StudentSupportTile` into a `live_component` with tile-local interaction state inputs and render a minimal but stable tile layout.
  - [ ] Implement namespaced URL param parsing/application for `tile_support[...]` in the dashboard coordination flow.
  - [ ] Implement a thin `student_support_chart` LiveView hook with a minimal Vega-Lite donut renderer and semantic click event forwarding.
  - [ ] Render a minimal right-side student list driven by the selected bucket and validate list synchronization against donut selection.
  - [ ] Add explicit guards so tile-local URL patches reuse the current snapshot/projection and do not invalidate scope-wide hydration.
  - [ ] Add targeted logging/telemetry to detect unexpected scope-wide reloads or invalid browser payloads during tile-local interaction.
- Testing Tasks:
  - [ ] Add unit tests for bucket precedence, inactivity derivation, default-bucket fallback, and student-row shaping.
  - [ ] Add LiveView tests proving:
    - donut selection updates the list
    - `tile_support[...]` patching rehydrates tile state
    - browser `back` restores tile state
    - tile-local patches do not reload unrelated dashboard data paths
  - [ ] Add minimal hook/browser validation for chart click forwarding if practical; otherwise cover through LiveView integration plus manual verification.
  - Command(s): `mix test test/oli/instructor_dashboard test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Support tile data arrives through the intended snapshot/projection path.
  - Minimal donut interaction, URL patching, and student-list synchronization work end-to-end.
  - Default-bucket fallback works when `struggling` is empty.
  - Tile-local patches do not trigger scope-wide oracle reload.
- Gate:
  - Architecture gate: confirm whether Vega-Lite supports the minimum required interaction set for this tile (`segment selection`, `highlighted selected state`, `URL patch sync`, `state rehydration`, and `list sync`) without excessive workaround complexity.
- Dependencies:
  - Depends on the current dashboard shell/tab architecture and the concrete-oracles contracts being stable enough to supply progress/proficiency and student info inputs.
- Parallelizable Work:
  - Projection test authoring can run in parallel with the minimal `live_component` shell.
  - Hook implementation can proceed in parallel with URL param parsing once the event contract is fixed.

## Phase 2: PR 2 - UI Refinement, Chart Decision Follow-through, and Full Tile Interaction
- Goal: Refine the tile to match the intended UX more closely, using the Phase 1 architecture as the fixed base and either confirming Vega-Lite as viable or replacing only the renderer/hook layer if needed.
- Tasks:
  - [ ] Run `implement_ui` against the three Jira-linked Figma states and capture token/icon/component mapping decisions needed for final UI implementation.
  - [ ] Refine the tile layout, spacing, hierarchy, and empty-state presentation to match the approved design direction.
  - [ ] Complete the legend, active/inactive filter, search input, and `Load more` interaction behavior on top of the existing URL/projection contract.
  - [ ] Improve the chart selected/hover/legend synchronization and responsive behavior.
  - [ ] If Phase 1 shows Vega-Lite is insufficient, replace only the renderer/hook layer while preserving the same tile-local state and URL contracts.
  - [ ] Add keyboard/focus/screen-reader affordances required for chart/list/filter interaction.
- Testing Tasks:
  - [ ] Expand LiveView tests for filter, search, and pagination behaviors.
  - [ ] Add targeted tests for any renderer replacement path if Vega-Lite is dropped.
  - [ ] Perform manual QA against the Jira-linked Figma states for default, hover, no-inactive, and empty-state scenarios.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Tile interaction model is complete for bucket/filter/search/pagination.
  - UI is intentionally designed and materially closer to Figma.
  - Accessibility and responsive behavior are validated for the supported tile states.
  - The renderer choice is settled: either Vega-Lite is retained confidently or replaced cleanly without changing higher-level contracts.
- Gate:
  - UX gate: product/design review can confirm the tile is viable visually and behaviorally for the dashboard without reopening architecture decisions.
- Dependencies:
  - Depends on Phase 1 completing and resolving the chart-runtime viability question.
- Parallelizable Work:
  - `implement_ui` brief generation can happen in parallel with interaction/a11y refinement.
  - Renderer replacement work, if needed, can run in parallel with non-chart list/filter polish because contracts are already fixed.

## Phase 3: PR 3 - Student Actions, Email Handoff, and Final Integration Hardening
- Goal: Complete the user-action side of the tile by adding stable row selection and email handoff on top of the validated tile architecture and polished UI.
- Tasks:
  - [ ] Implement row and master selection semantics for the currently visible list only.
  - [ ] Wire `Email` enable/disable behavior to the selected visible-student set.
  - [ ] Integrate the tile with the downstream email flow using the existing email entrypoint/context contract.
  - [ ] Ensure navigation from the tile into student-specific destinations preserves and restores tile state through URL params.
  - [ ] Add final hardening around selection state, invalid payloads, and empty/edge cases.
- Testing Tasks:
  - [ ] Add LiveView tests for row/master selection and visible-list-only selection behavior.
  - [ ] Add tests proving `Email` remains disabled until selection is non-empty and opens with the correct recipients/context when enabled.
  - [ ] Perform manual QA for selection persistence expectations, email handoff, and browser `back` behavior from downstream navigation.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Selection behavior is correct and scoped to the visible list.
  - Email handoff works with the expected recipients and context.
  - The tile is functionally complete for `MER-5252`, leaving only downstream follow-up stories (`MER-5255`, `MER-5256`) outside this scope.
- Gate:
  - Feature-complete gate: instructors can use the tile to identify a student subset, preserve context through navigation, and initiate outreach from the selected list.
- Dependencies:
  - Depends on Phase 2 for settled tile interaction and UI behavior.
- Parallelizable Work:
  - Email handoff wiring can proceed in parallel with some final selection-edge-case tests once selection contracts are stable.

## Parallelization Notes
- The highest-risk validation work is intentionally front-loaded into Phase 1 so the team can pivot early if the chart renderer choice is wrong.
- Adjacent dashboard-tile development can continue in parallel as long as shared changes to `dashboard_ui_composition.md`, dashboard param parsing, and common shell/tab behavior are coordinated and reviewed carefully.
- Keep PR scope disciplined:
  - PR 1 proves architecture and data/state flow
  - PR 2 proves polished interaction and visual viability
  - PR 3 proves action/handoff completeness
- Avoid bundling Figma-perfect styling into PR 1; doing so would hide whether architecture or visual detail is causing problems.

## Phase Gate Summary
- Gate A: Phase 1 proves that projection wiring, URL-backed tile state, and chart/list synchronization work without scope-wide refetch; it also answers whether Vega-Lite is viable enough to continue.
- Gate B: Phase 2 proves the chosen renderer and tile architecture can satisfy the intended UX and accessibility expectations.
- Gate C: Phase 3 proves instructor actions (selection, navigation, and email handoff) are correct and completes the feature scope.

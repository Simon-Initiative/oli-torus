# Progress Tile - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/progress_tile/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/progress_tile/fdd.md`

## Scope
Deliver `MER-5251` in dependency-ordered increments that validate the tile architecture early, preserve the oracle/projection/UI split already established by the dashboard epic, and land the final instructor-facing chart behavior only after the data contract and URL-backed tile state are stable.

This plan intentionally separates:

- projection and mixed-child axis contract work
- LiveComponent state ownership and namespaced URL param behavior
- chart runtime, schedule visualization, pagination, and accessibility hardening
- final verification against Figma and dashboard integration boundaries

## Clarifications & Default Assumptions
- The tile must render the direct children of the current scope even when the children are structurally mixed.
- When the direct children are mixed, the axis label should use the approved generic copy `Course Content`.
- Tile-local navigation state will be URL-backed using namespaced params:
  - `tile_progress[threshold]`
  - `tile_progress[mode]`
  - `tile_progress[page]`
- Tile-param changes must reuse already loaded snapshot/projection data and must not trigger scope-wide oracle reload.
- The initial concrete data dependency is still the progress-bins plus scope-resources pair defined by the dashboard oracle work.
- The exact upstream schedule payload remains the main unresolved technical question and should be treated as a gate in Phase 1.
- The tile should become a `Phoenix.LiveComponent` once real local interaction state is introduced.

## Phase 1: Projection Contract, Mixed-Child Axis Rules, and Upstream Wiring
- Goal: Lock the non-UI data contract for the Progress tile so the feature has a stable projection boundary before meaningful UI work begins.
- Tasks:
  - [ ] Replace or evolve the current prototype-style Progress tile projection path into a feature-owned projection module that consumes progress-bins, scope-resources, and optional schedule metadata from the dashboard snapshot/runtime path.
  - [ ] Model the projection around direct children of the current scope rather than a single homogeneous axis type.
  - [ ] Include per-item resource type metadata in the projected series and implement the generic axis-label fallback `Course Content` for mixed-child scopes.
  - [ ] Define deterministic projection output for class size, threshold-aware counts, count/percent values, pagination slices, schedule marker metadata, and empty states.
  - [ ] Confirm or document the upstream source for schedule marker payloads; if the exact contract is still unresolved, define a no-schedule fallback path that keeps the tile functional.
  - [ ] Align the engagement-section/dashboard-shell wiring so the tile can receive the required projection input without direct analytics access in UI code.
  - [ ] Covers: `AC-001`, `AC-002`, `AC-003`, `AC-005`, `AC-007`, `AC-011`, `AC-012`.
- Testing Tasks:
  - [ ] Add Elixir unit tests for direct-child resolution in homogeneous and mixed scopes.
  - [ ] Add unit tests for threshold application, count vs percent derivation, generic axis-label fallback, empty states, and schedule/no-schedule projection behavior.
  - [ ] Add targeted tests for graceful fallback when schedule metadata is unavailable or incomplete.
  - Command(s): `mix test test/oli/instructor_dashboard`
- Definition of Done:
  - Progress tile projection is feature-owned, deterministic, and free of HEEx/browser concerns.
  - Mixed-child scopes are modeled correctly and produce the expected axis label and per-item metadata.
  - The feature has a documented answer or explicit fallback for missing schedule payload details.
- Gate:
  - Data-contract gate: projection output is stable enough that UI work can proceed without reopening oracle/projection boundaries.
- Dependencies:
  - Depends on the dashboard runtime/snapshot path being available enough to supply progress and scope-resource inputs.
- Parallelizable Work:
  - Projection tests can proceed in parallel with upstream wiring once the output shape is fixed.
  - Schedule-payload investigation can proceed in parallel with non-schedule projection work.

## Phase 2: LiveComponent, URL-Backed Tile State, and Minimal Interactive Slice
- Goal: Prove the tile interaction model end-to-end in LiveView before final chart polish, with the component owning tile-local state and synchronizing it to namespaced URL params.
- Tasks:
  - [ ] Convert `ProgressTile` from placeholder rendering into a `Phoenix.LiveComponent`.
  - [ ] Parse and apply `tile_progress[...]` params in the dashboard/tile flow using the shared namespacing rules from `dashboard_ui_composition.md`.
  - [ ] Implement tile-local state transitions for threshold, mode, and pagination using URL patches that do not trigger scope-wide oracle reload when dashboard scope identity is unchanged.
  - [ ] Render stable tile chrome: title, CTA, class size, threshold control, y-axis mode control, empty states, and chart mount target.
  - [ ] Ensure state is clamped or reset correctly when scope changes invalidate the current tile page or control values.
  - [ ] Implement navigation wiring for `View Progress Details`.
  - [ ] Covers: `AC-004`, `AC-006`, `AC-008`, `AC-010`, `AC-013`.
- Testing Tasks:
  - [ ] Add LiveView tests proving threshold, mode, and page params rehydrate the tile correctly.
  - [ ] Add tests proving tile-local URL patches do not trigger broader scope reload behavior.
  - [ ] Add LiveView tests for CTA routing, class size display, and empty-state rendering.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Progress tile state is owned locally by the tile and is restored from namespaced URL params.
  - Threshold/mode/page changes rerender the tile from existing projected data without scope-wide reload.
  - The tile is navigable and minimally usable before chart polish.
- Gate:
  - Interaction-state gate: the LiveComponent and URL-backed state model are stable enough that renderer work can proceed without changing higher-level ownership.
- Dependencies:
  - Depends on Phase 1 for stable projection output and mixed-child axis semantics.
- Parallelizable Work:
  - CTA routing and control rendering can proceed in parallel with URL-param parsing once the tile event contract is fixed.
  - Empty-state rendering tests can proceed in parallel with URL-backed state work.

## Phase 3: Chart Renderer, Schedule Visualization, Pagination UX, and Accessibility Hardening
- Goal: Land the final chart-driven user experience, including schedule visualization, mixed-child axis presentation, pagination behavior, and accessibility expectations.
- Tasks:
  - [ ] Implement a thin `ProgressTileChart` hook or equivalent browser runtime following the established LiveView hook pattern.
  - [ ] Render the projected chart data in Vega-Lite without moving threshold, mixed-child axis, or schedule logic into the browser layer.
  - [ ] Implement the dotted schedule marker and behind-schedule visual treatment when schedule metadata is present.
  - [ ] Implement paginated chart navigation with correct enabled/disabled states and visible-range updates.
  - [ ] Ensure long labels truncate visually while preserving full accessible disclosure.
  - [ ] Finalize axis-label copy handling so homogeneous scopes can use specific wording and mixed scopes use `Course Content`.
  - [ ] Add keyboard, screen-reader, tooltip, and `aria-live` behavior required by the PRD.
  - [ ] Run a final Figma comparison pass against the selected node and Jira-linked variants.
  - [ ] Covers: `AC-009`, `AC-010`, `AC-011`, `AC-014`, `AC-015`.
- Testing Tasks:
  - [ ] Add JS/hook tests or equivalent integration coverage for chart mount/update/destroy and stale-render suppression.
  - [ ] Add LiveView/integration tests for pagination state, schedule/no-schedule rendering, long-label disclosure, and mixed-child axis-copy behavior.
  - [ ] Perform manual accessibility QA at keyboard-only and 200% zoom, including tooltip triggers and `aria-live` announcements.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - The final chart renderer is integrated without violating the oracle/projection/UI boundary.
  - Schedule visualization, mixed-child axis labeling, pagination, and accessibility behaviors match the approved product/design decisions.
  - The tile is implementation-complete for `MER-5251`.
- Gate:
  - Feature-complete gate: instructors can use the Progress tile end-to-end with stable state, correct chart semantics, and approved UX behavior.
- Dependencies:
  - Depends on Phase 2 for stable component and URL-state ownership.
- Parallelizable Work:
  - Hook implementation can proceed in parallel with accessibility copy/label work once the chart payload contract is fixed.
  - Figma comparison and manual QA prep can proceed in parallel with final automated test authoring.

## Parallelization Notes
- The highest-risk uncertainty is still the schedule payload contract, so it is intentionally surfaced in Phase 1 instead of being deferred.
- Mixed-child axis semantics are now a first-class requirement; avoid starting renderer work before the projection contract is settled around direct children and axis-label fallback.
- Keep PR scope disciplined:
  - PR 1 proves projection and mixed-child semantics
  - PR 2 proves component ownership and URL-backed state
  - PR 3 proves final chart behavior and accessibility
- Avoid bundling Figma-perfect chart polish into the earliest slice; first prove that the data contract and state model are correct.

## Phase Gate Summary
- Gate A: Phase 1 proves the non-UI projection contract, mixed-child axis behavior, and schedule fallback posture.
- Gate B: Phase 2 proves URL-backed tile state, LiveComponent ownership, and no scope-wide reload on tile-local changes.
- Gate C: Phase 3 proves final chart rendering, schedule visualization, accessibility, and feature completeness.

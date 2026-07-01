# Dashboard Tile Chrome (Instructor-Section Layout Chrome) — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/tile_chrome/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/tile_chrome/fdd.md`

## Scope
Deliver reusable instructor-dashboard section chrome for the Intelligent Dashboard `Engagement` and `Content` groups, including collapse/expand, client-driven drag-and-drop reorder, instructor-section persistence by `enrollment_id`, dashboard-side tile eligibility filtering, and required LiveView coverage. This work stays inside Lane 2 of the Intelligent Dashboard epic and must remain compatible with existing dashboard scope persistence in `InstructorDashboardState`.

## Scenario Testing Contract
- Status: Not applicable
- Infrastructure Support Status: Supported
- Scenario Infrastructure Expansion Required: No
- Scope (AC/workflows): `N/A`
- Planned Artifacts: `N/A`
- Validation Commands: `N/A`
- Skill Handoff: `N/A`

## LiveView Testing Contract
- Status: Required
- Scope (events/states):
  - `AC-002` collapse/expand state changes
  - `AC-003` reorder apply path
  - `AC-004` instructor-section persistence restore across refresh/scope change
  - `AC-005` zero-tile section omission
  - `AC-006` single-tile full-width section rendering
  - `AC-007` invalid reorder payload rejection
  - `AC-008` collapse state preserved after reorder
- Planned Artifacts:
  - `test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - `test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
  - `test/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome_test.exs`
- Validation Commands:
  - `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
  - `mix test test/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome_test.exs`

## Non-Functional Guardrails
- Persist layout by `enrollment_id` only; do not introduce section-shared state.
- Keep tile eligibility and section omission in Intelligent Dashboard composition, not in the reusable chrome component.
- Reuse the existing Remix-style native hook + LiveView pattern; do not introduce a new drag-and-drop library.
- Maintain WCAG AA semantics:
  - keyboard reachable caret and drag handle
  - `Shift + ArrowUp` / `Shift + ArrowDown` reorder behavior
  - no focusable artifacts for omitted sections
- Keep instrumentation minimal:
  - layout-save failure count
  - restore failure count
- Do not add dedicated performance/load/benchmark tasks.

## Clarifications & Default Assumptions
- Assumption: the user request `chrome_tile` refers to `docs/exec-plans/current/epics/intelligent_dashboard/tile_chrome`.
- Assumption: the reusable chrome file moves to `lib/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome.ex`, while Intelligent Dashboard composition files remain under `.../intelligent_dashboard/`.
- Assumption: default section order is `["engagement", "content"]` when no persisted row or no persisted layout fields exist.
- Assumption: default collapsed state is `[]`, meaning all visible sections start expanded.
- Assumption: keyboard reorder uses the same pattern as Remix (`Shift + ArrowUp` / `Shift + ArrowDown`) and no separate up/down visual controls are added in this story.
- Assumption: if persistence fails after a drop/toggle, LiveView reverts to the last stable server-known state and surfaces an error.

## Phase 1: Persistence Contract and Section State Resolution
- Goal: establish the enrollment-scoped persistence model and deterministic layout-state resolution used by the dashboard shell.
- Tasks:
  - [ ] Extend `instructor_dashboard_states` with `section_order` and `collapsed_section_ids` fields using a reversible migration.
  - [ ] Update `Oli.InstructorDashboard.InstructorDashboardState` schema/types/changeset to accept the new fields alongside `last_viewed_scope`.
  - [ ] Extend `Oli.InstructorDashboard.upsert_state/2` to persist the new layout attributes without regressing `last_viewed_scope`.
  - [ ] Add a helper/resolution path that computes stable layout defaults when persisted values are absent, stale, or partially populated (`AC-004`, `AC-008`).
  - [ ] Keep restore rules explicit:
    - ignore unknown section ids
    - append newly visible sections in default order
    - derive expanded state from `collapsed_section_ids`
  - [ ] Add minimal failure instrumentation for save/restore paths.
- Testing Tasks:
  - [ ] Add/update context tests for enrollment-scoped upsert/readback of section layout fields (`AC-004`).
  - [ ] Add tests for default resolution with no persisted layout and with stale ids in persisted layout (`AC-004`, `AC-008`).
  - Command(s): `mix test test/oli/instructor_dashboard_test.exs`
- Definition of Done:
  - Layout fields persist correctly by `enrollment_id`.
  - Restore helpers produce deterministic defaults and stale-id handling.
  - Existing scope persistence behavior still passes.
- Gate:
  - Enrollment-scoped persistence tests pass and migration is reversible.
- Dependencies:
  - None.
- Parallelizable Work:
  - Migration/schema updates and restore-rule unit tests can proceed in parallel until they need the final field names aligned.

## Phase 2: Reusable Chrome Component and Client Hook
- Goal: implement the reusable section chrome and the client-side reorder hook using the existing Torus native-hook pattern.
- Tasks:
  - [ ] Move/create the reusable chrome component at `lib/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome.ex`.
  - [ ] Implement section header rendering, caret button, drag handle, DOM/data attributes, tooltip trigger, and collapsed rendering behavior (`AC-001`, `AC-002`).
  - [ ] Add a dedicated hook file under `assets/src/hooks/dashboard_section_chrome.ts` and register it in `assets/src/hooks/index.ts`.
  - [ ] Implement pointer drag lifecycle in the hook using the Remix-style native approach:
    - local hover/placeholder/preview state during drag
    - final ordered ids emitted only on drop (`AC-003`)
  - [ ] Implement keyboard reorder with `Shift + ArrowUp` / `Shift + ArrowDown` routed through the same reorder event path (`AC-003`, `AC-007`).
  - [ ] Ensure the hook/component contract uses canonical section ids only, never DOM ids as persistence keys.
  - [ ] Keep drag constrained to top-level sections only and reject malformed payloads at the LiveView boundary (`AC-007`).
- Testing Tasks:
  - [ ] Add component tests for chrome rendering, collapsed/expanded states, and visible controls (`AC-001`, `AC-002`, `AC-006`).
  - [ ] Add targeted tests for keyboard reorder event generation/handling contract (`AC-003`, `AC-007`).
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome_test.exs`
- Definition of Done:
  - Chrome component is reusable outside `intelligent_dashboard`.
  - Hook is registered and emits only stable final reorder payloads.
  - Keyboard reorder follows the Remix interaction pattern.
- Gate:
  - Component-level tests pass and no new drag library is introduced.
- Dependencies:
  - Phase 1 field names and restore contract finalized.
- Parallelizable Work:
  - HEEx chrome rendering and hook implementation can be developed in parallel once the event names and payload shape are fixed.

## Phase 3: Intelligent Dashboard Composition and LiveView Integration
- Goal: wire the reusable chrome into Intelligent Dashboard composition, including visibility rules, default order, persistence restore, and stable post-drop server state.
- Tasks:
  - [ ] Update Intelligent Dashboard shell/composition to build section definitions with canonical ids and derived `expanded` state (`AC-001`, `AC-004`).
  - [ ] Implement eligibility filtering before chrome render:
    - omit `Content` when both tiles are ineligible (`AC-005`)
    - omit zero-tile sections entirely (`AC-005`, `AC-007`)
    - render single-tile sections full width while keeping chrome controls (`AC-006`)
  - [ ] Integrate persisted order and collapsed state into shell assigns and ensure LiveView keeps the stable current order after each successful drop (`AC-003`, `AC-004`).
  - [ ] Add/tighten LiveView events for:
    - `dashboard_section_toggled`
    - `dashboard_sections_reordered`
  - [ ] Ensure reorder never changes collapse state and never permits cross-section tile movement (`AC-007`, `AC-008`).
  - [ ] Implement failure handling so persistence/save errors revert to the last stable server-known order/expand state and surface error feedback.
  - [ ] Keep scope navigation and layout persistence independent so layout survives dashboard scope changes (`AC-004`).
- Testing Tasks:
  - [ ] Add/update LiveView tests for toggle, reorder, persistence restore, and scope-change restore (`AC-002`, `AC-003`, `AC-004`, `AC-008`).
  - [ ] Add LiveView tests for hidden `Content` and single-tile full-width rendering (`AC-005`, `AC-006`).
  - [ ] Add invalid payload rejection coverage (`AC-007`).
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
- Definition of Done:
  - Intelligent Dashboard renders sections through the reusable chrome only.
  - Post-drop state is client-fluid during drag but server-authoritative after drop.
  - Visibility, persistence, and reorder invariants hold across refreshes and scope changes.
- Gate:
  - LiveView tests covering `AC-002` through `AC-008` pass.
- Dependencies:
  - Phase 1 persistence contract.
  - Phase 2 chrome + hook event contract.
- Parallelizable Work:
  - Section eligibility composition and persistence restore wiring can proceed in parallel until final integration into the shell template.

## Phase 4: Accessibility, Hardening, and Spec/Traceability Closure
- Goal: close remaining a11y and operational gaps, then land the feature pack in a fully validated state.
- Tasks:
  - [ ] Verify focus order, omitted-section absence from tab sequence, and keyboard reorder behavior against the Figma/Jira guidance (`AC-002`, `AC-005`, `AC-007`).
  - [ ] Confirm tooltip labeling and control semantics for caret/drag handle.
  - [ ] Review logs/instrumentation to ensure save/restore failure context is sufficient and not noisy.
  - [ ] Update any code comments or nearby docs affected by the chrome move and persistence semantics.
  - [ ] Reconcile `docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md` and this feature pack if implementation details drift.
- Testing Tasks:
  - [ ] Run targeted LiveView/component suites after final integration.
  - [ ] Perform manual QA for pointer drag/drop and keyboard-only reorder walkthrough.
  - Command(s): `mix test test/oli/instructor_dashboard_test.exs`
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
- Definition of Done:
  - Accessibility-critical flows are verified.
  - Minimal instrumentation is in place.
  - Feature-spec docs and implementation plan stay aligned.
- Gate:
  - All targeted tests pass and manual QA finds no blocking regressions in drag, toggle, restore, or focus behavior.
- Dependencies:
  - Phases 1-3 complete.
- Parallelizable Work:
  - Manual QA and doc reconciliation can run in parallel after automated tests are green.

## Parallelisation Notes
- Phase 1 must complete before Phases 2 and 3 fully integrate because the persistence field names and restore behavior are foundational.
- Within Phase 2, component markup/styling and hook implementation are parallel tracks once event payloads are fixed.
- Within Phase 3, eligibility filtering logic and persistence restore logic are parallelizable until final shell integration.
- Phase 4 starts only after feature behavior is stable, but manual QA and spec reconciliation are safe to run concurrently.

## Phase Gate Summary
- Gate 1: enrollment-scoped persistence contract is migrated, reversible, and test-covered.
- Gate 2: reusable chrome + native hook exist and pass component-level verification without a new drag library.
- Gate 3: Intelligent Dashboard integration passes LiveView coverage for `AC-002` through `AC-008`.
- Gate 4: targeted automated suites and manual a11y/interaction checks pass, and plan/spec validation remains green.

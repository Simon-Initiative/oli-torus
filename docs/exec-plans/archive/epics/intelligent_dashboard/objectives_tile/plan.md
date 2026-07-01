# Challenging Objectives Tile - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/objectives_tile/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/objectives_tile/fdd.md`

## Scope

Deliver the `Challenging Objectives` tile for Instructor Intelligent Dashboard using the existing oracle/snapshot/projection architecture. The plan covers the missing consumer binding, correction of the existing `challenging_objectives` projection, HEEx tile rendering and disclosure behavior, deep-link handoff into `Insights -> Learning Objectives`, and the targeted automated coverage needed to satisfy `AC-001` through `AC-011`. This work must not introduce tile-local analytics queries, schema changes, or a separate rendering runtime.

## Clarifications & Default Assumptions

- Assumption: the work item keeps using `docs/exec-plans/current/epics/intelligent_dashboard/objectives_tile` as the canonical artifact directory.
- Assumption: no feature flag is introduced for this slice; rollout follows normal Intelligent Dashboard delivery flow.
- Assumption: `ObjectivesProficiencyOracle` plus `ScopeResourcesOracle` are sufficient for the tile when combined with `SectionResourceDepot` hierarchy reconstruction.
- Assumption: the Learning Objectives destination may be extended with additive URL params for initial filter/card/expanded-row state.
- Assumption: unresolved product questions about parent-row visibility and row caps do not block the first implementation if the team chooses a documented default before coding.

## Phase 1: Dependency Contract and Projection Correction

- Goal: make the tile a first-class dashboard consumer with the correct data dependencies and projection semantics.
- Tasks:
  - [ ] Add a `challenging_objectives` consumer profile in `Oli.InstructorDashboard.OracleBindings` that requires `:oracle_instructor_objectives_proficiency` and `:oracle_instructor_scope_resources` (`AC-001`, `AC-002`, `AC-008`, `AC-009`, `AC-010`, `AC-011`).
  - [ ] Replace the current `Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives` `progress_proxy` implementation with a tile-specific projection contract (`AC-002`, `AC-003`, `AC-008`, `AC-009`, `AC-010`, `AC-011`).
  - [ ] Implement projection logic that:
    - reconstructs objective hierarchy with `SectionResourceDepot`
    - preserves curriculum order/numbering
    - emits distinct populated / no-data / empty-low-proficiency states
    - returns deterministic navigation metadata for parent, child, and view-all actions (`AC-002`, `AC-003`, `AC-008`, `AC-009`, `AC-010`)
  - [ ] Ensure projection failures degrade to projection status/unavailable behavior instead of stale or misleading tile output (`AC-008`, `AC-009`, `AC-010`, `AC-011`).
  - [ ] Add or update minimal telemetry/logging for projection derivation and unresolved hierarchy mapping.
- Testing Tasks:
  - [ ] Add/update ExUnit coverage for `Oli.InstructorDashboard.OracleBindings` and `Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives` (`AC-001`, `AC-002`, `AC-003`, `AC-008`, `AC-009`, `AC-010`).
  - [ ] Verify the projection remains deterministic for identical scope inputs (`AC-011`).
  - Command(s): `mix test test/oli/instructor_dashboard/oracle_bindings_test.exs`
  - Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/projections/challenging_objectives_test.exs`
- Definition of Done:
  - The tile has a correct consumer binding and no longer depends on placeholder progress data.
  - Projection output can represent populated, no-data, and empty states without UI-side reshaping.
  - Unit tests for dependency and projection behavior are green.
- Gate:
  - Consumer binding and projection tests pass, and no tile-local query path has been introduced.
- Dependencies:
  - Existing concrete objective/scope-resource oracles available in the repo.
- Parallelizable Work:
  - Consumer binding changes and projection test authoring can proceed in parallel until final projection keys/payload shape are locked.

## Phase 2: Tile Rendering and Intelligent Dashboard Integration

- Goal: render the actual tile in the Intelligent Dashboard using typed projection data and accessible disclosure behavior.
- Tasks:
  - [ ] Replace the placeholder-only markup in `challenging_objectives_tile.ex` with typed rendering for populated, no-data, unavailable, and empty-low-proficiency states (`AC-001`, `AC-002`, `AC-008`, `AC-009`, `AC-010`).
  - [ ] Implement parent/sub-objective disclosure behavior with keyboard-operable controls, visible focus state, and expanded-state semantics (`AC-003`, `AC-004`).
  - [ ] Update `IntelligentDashboardTab` and related shell assigns so the tile consumes typed projection data/status instead of `objectives_status` debug text (`AC-001`, `AC-002`, `AC-011`).
  - [ ] Reset tile-local expanded-row state whenever the projection identity changes so old scope rows cannot remain visually expanded (`AC-011`).
  - [ ] Preserve existing section-level eligibility logic (`has_objectives_tile?/2`) so the tile remains hidden when no objectives exist for the scope (`AC-008`).
  - [ ] Add tile-level telemetry for objective, sub-objective, and view-all interactions.
- Testing Tasks:
  - [ ] Add component or LiveView rendering tests for populated rows, disclosure controls, no-objectives suppression, no-data state, and empty-low-proficiency state (`AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-008`, `AC-009`, `AC-010`).
  - [ ] Add a targeted Intelligent Dashboard LiveView test proving rapid scope changes only render latest-scope tile data (`AC-011`).
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
- Definition of Done:
  - The tile renders real projection data in Intelligent Dashboard.
  - Disclosure behavior is accessible and state-reset rules prevent stale visual carryover.
  - Dashboard integration no longer relies on prototype-only `objectives_text` for primary tile behavior.
- Gate:
  - Tile rendering tests and rapid-scope regression coverage pass.
- Dependencies:
  - Phase 1 projection contract complete.
- Parallelizable Work:
  - HEEx tile rendering and `IntelligentDashboardTab` assign wiring can proceed in parallel once the projection payload shape is fixed.

## Phase 3: Deep-link Handoff to Learning Objectives

- Goal: make tile actions land in `Insights -> Learning Objectives` with deterministic scope and expansion context.
- Tasks:
  - [ ] Define and implement additive URL params for parent objective, sub-objective, and view-all navigation (`AC-005`, `AC-006`, `AC-007`).
  - [ ] Update `InstructorDashboardLive` and/or `LearningObjectives` initialization so those params seed `filter_by`, `selected_card_value`, and initial `expanded_objectives` state deterministically (`AC-005`, `AC-006`, `AC-007`).
  - [ ] Ensure invalid or unresolved params fall back to the default Learning Objectives view without crashing (`AC-005`, `AC-006`, `AC-007`).
  - [ ] Keep the destination changes additive so existing Learning Objectives entry points still behave the same when tile params are absent.
- Testing Tasks:
  - [ ] Add targeted LiveView/component coverage for objective click, sub-objective click, and view-all navigation contracts (`AC-005`, `AC-006`, `AC-007`).
  - [ ] Add invalid-param fallback coverage on the destination page (`AC-005`, `AC-006`, `AC-007`).
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - Command(s): `mix test test/oli_web/components/delivery/learning_objectives_test.exs`
- Definition of Done:
  - Tile links land in Learning Objectives with the intended context for objective, sub-objective, and view-all flows.
  - Destination initialization is deterministic and additive.
- Gate:
  - Deep-link tests are green and manual spot-check confirms the expected arrival state.
- Dependencies:
  - Phase 2 tile rendering completed so link generation uses the final projection payload.
- Parallelizable Work:
  - Destination param parsing and tile link generation can be developed in parallel once the URL contract is agreed.

## Phase 4: Verification, Hardening, and Spec Closure

- Goal: finish non-functional verification, align docs with implementation, and close the work item cleanly.
- Tasks:
  - [ ] Run the targeted backend and LiveView/component suites for this feature (`AC-001` through `AC-011`).
  - [ ] Run formatting for touched Elixir files and any frontend formatting if asset code was added.
  - [ ] Manually verify keyboard-only disclosure, scope switching, and deep-link arrival behavior.
  - [ ] Reconcile any implementation drift back into work-item docs if behavior changed during execution.
  - [ ] Confirm telemetry/events and warning logs are present but not noisy.
- Testing Tasks:
  - [ ] Re-run targeted unit and LiveView/component suites after final integration (`AC-001` through `AC-011`).
  - [ ] Capture manual QA notes for the three critical workflows:
    - tile populated interaction
    - empty/no-data/no-objectives distinction
    - drill-through into Learning Objectives
  - Command(s): `mix test test/oli/instructor_dashboard/oracle_bindings_test.exs`
  - Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/projections/challenging_objectives_test.exs`
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - Command(s): `mix format`
- Definition of Done:
  - Targeted automated coverage is green.
  - Manual QA finds no blocking issues in disclosure, scope updates, or drill-through behavior.
  - Work-item docs remain aligned with the implemented behavior.
- Gate:
  - All targeted tests pass, formatting is clean, and manual QA is complete.
- Dependencies:
  - Phases 1-3 complete.
- Parallelizable Work:
  - Manual QA and doc reconciliation can run in parallel after automated tests pass.

## Parallelization Notes

- Phase 1 is foundational because the corrected consumer binding and projection contract drive every downstream task.
- Within Phase 2, tile HEEx rendering and LiveView assign wiring are parallelizable once the projection payload is fixed.
- Within Phase 3, destination param parsing and tile link generation are parallelizable once the URL contract is fixed.
- Phase 4 begins after implementation stabilizes, but manual QA and doc updates are safe to perform concurrently.

## Phase Gate Summary

- Gate 1: `challenging_objectives` consumer binding and corrected projection contract are implemented and test-covered.
- Gate 2: the tile renders typed projection data accessibly and survives rapid scope changes without stale results.
- Gate 3: deep-link flows for objective, sub-objective, and view-all actions land in Learning Objectives with deterministic context.
- Gate 4: targeted tests, formatting, and manual QA all pass, and docs remain aligned with code.
